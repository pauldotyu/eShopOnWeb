using Microsoft.AspNetCore.Mvc;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.CoreSkills;
using Microsoft.SemanticKernel.Memory;

var builder = WebApplication.CreateBuilder(args);

// Add configuration
builder.Configuration
  .AddJsonFile("appsettings.local.json", optional: true)
  .AddEnvironmentVariables();

// Azure OpenAI settings
var aoaiSettings = builder.Configuration.GetSection("AzureOpenAISettings").Get<AzureOpenAISettings>();

// Azure OpenAI via SemanticKernel
var kernel = Kernel.Builder
  .Configure(c => 
  {
    // c.AddAzureChatCompletionService(
    //     aoaiSettings.ChatCompletionModel.Alias,
    //     aoaiSettings.ChatCompletionModel.DeploymentName,
    //     aoaiSettings.Endpoint,
    //     aoaiSettings.Key);
    c.AddAzureTextEmbeddingGenerationService(
        aoaiSettings.EmbeddingGenerationModel.Alias,
        aoaiSettings.EmbeddingGenerationModel.DeploymentName,
        aoaiSettings.Endpoint,
        aoaiSettings.Key
    );
    c.AddAzureTextCompletionService(
        aoaiSettings.TextCompletionModel.Alias,
        aoaiSettings.TextCompletionModel.DeploymentName,
        aoaiSettings.Endpoint,
        aoaiSettings.Key
    );
  })
  .WithMemoryStorage(new VolatileMemoryStore())
  .Build();

builder.Services.AddSingleton<IKernel>(kernel);

builder.Services.AddCors();

var app = builder.Build();

app.UseCors(builder => builder
 .AllowAnyOrigin()
 .AllowAnyMethod()
 .AllowAnyHeader()
);

app.MapGet("/", () => "Hello World!");

app.MapPost("/shopassist", async ([FromServices]IKernel kernel, [FromBody]ChatRequest req) => {
  const string MemoryCollectionName = "products";
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "1", text: ".NET Bot Black Sweatshirt");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "2", text: ".NET Black & White Mug");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "3", text: "Prism White T-Shirt");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "4", text: ".NET Foundation Sweatshirt");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "5", text: "Roslyn Red Sheet");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "6", text: ".NET Blue Sweatshirt");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "7", text: "Roslyn Red T-Shirt");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "8", text: "Kudu Purple Sweatshirt");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "9", text: "Cup<T> White Mug");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "10", text: ".NET Foundation Sheet");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "1", text: "Cup<T> Sheet");
  await kernel.Memory.SaveInformationAsync(MemoryCollectionName, id: "12", text: "Prism White TShirt");

  kernel.ImportSkill(new TextMemorySkill());

  var prompt = @"eShopBot can have a conversation with you about any topic.
  It can give explicit instructions or say 'I don't know' if it does not have an answer.

  Information about products, from previous conversations:
  - {{$fact1}} {{recall $fact1}}
  - {{$fact2}} {{recall $fact2}}
  - {{$fact3}} {{recall $fact3}}
  - {{$fact4}} {{recall $fact4}}
  - {{$fact5}} {{recall $fact5}}

  Chat:
  {{$history}}
  User: {{$userInput}}
  eShopBot: ";

  var chatFunction = kernel.CreateSemanticFunction(prompt, maxTokens: 200, temperature: 0.8);

  var context = kernel.CreateNewContext();
  context["fact1"] = "do you have sweatshirts?";
  context["fact2"] = "what kind of mugs do you sell?";
  context["fact3"] = "what are some t-shirts you sell?";
  context["fact4"] = "anything in the color white?";
  context["fact5"] = "how about things that are color red?";

  var history = "";
  context["history"] = history;

  var resp = string.Empty;

  Func<string, Task> Chat = async (string input) => {
    // Save new message in the context variables
    context["userInput"] = input;

    // Process the user message and get an answer
    var answer = await chatFunction.InvokeAsync(context);

    // Append the new interaction to the chat history
    history += $"\nUser: {input}\nChatBot: {answer}\n"; context["history"] = history;
    
    // Show the bot response
    resp = "eShopBot: " + context;
  };

  await Chat(req.Text);

  return Results.Ok(resp);
});

app.Run();

public class ChatRequest
{
    public string Text { get; set; } = string.Empty;
}

public class AzureOpenAISettings
{
    public string Endpoint { get; set; } = string.Empty;
    public string Key { get; set; } = string.Empty;
    public ModelDeployment ChatCompletionModel { get; set; }
    public ModelDeployment EmbeddingGenerationModel { get; set; }
    public ModelDeployment TextCompletionModel { get; set; }
}

public struct ModelDeployment {
  public string Alias { get; set; }
  public string DeploymentName { get; set; }
}