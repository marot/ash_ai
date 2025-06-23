defmodule AshAi.Actions.Prompt.PromptTest do
  use ExUnit.Case, async: true
  alias __MODULE__.{TestDomain, TestResource}

  defmodule TestResource do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshAi]

    actions do
      action :analyze_sentiment, Ash.Type.Boolean do
        description("Does the text contain positive or negative sentiment?")
        argument(:text, :string, allow_nil?: false)

        run prompt(LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}))
      end

      action :generate_summary, Ash.Type.Boolean do
        description("Does the text contain long words?")
        argument(:content, :string, allow_nil?: false)

        run prompt(LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}),
              prompt: "Are there long words? <%= @input.arguments.content %>"
            )
      end

      action :with_user_message, Ash.Type.Boolean do
        description("Does the text contain long words?")
        argument(:content, :string, allow_nil?: false)

        run prompt(LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}),
              prompt: {"Are there long words?", "Input: <%= @input.arguments.content %>"}
            )
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, extensions: [AshAi]

    resources do
      resource(TestResource)
    end
  end

  describe "extract_prompt/2" do
    test "successfully retrieves the prompt" do
      result =
        TestResource
        |> Ash.ActionInput.for_action(:analyze_sentiment, %{
          text: "This product is absolutely amazing!"
        })
        |> AshAi.Actions.Prompt.extract_prompt()

      assert %{
               tools: [],
               json_schema: %{"type" => "boolean"},
               system_prompt:
                 "You are responsible for performing the `analyze_sentiment` action.\n\n\n# Description\nDoes the text contain positive or negative sentiment?\n\n\n## Inputs\n\n- text\n\n",
               user_message:
                 "# Action Inputs\n\n\n  - text: \"This product is absolutely amazing!\"\n\n"
             } = result
    end

    test "successfully retrieves the custom system prompt" do
      result =
        TestResource
        |> Ash.ActionInput.for_action(:generate_summary, %{
          content: "This does not contain long words."
        })
        |> AshAi.Actions.Prompt.extract_prompt()

      assert %{
               json_schema: %{"type" => "boolean"},
               system_prompt: "Are there long words? This does not contain long words.",
               tools: [],
               user_message: "Perform the action"
             } = result
    end

    test "successfully retrieves the custom system and user prompt" do
      result =
        TestResource
        |> Ash.ActionInput.for_action(:with_user_message, %{
          content: "This does not contain long words."
        })
        |> AshAi.Actions.Prompt.extract_prompt()

      assert %{
               json_schema: %{"type" => "boolean"},
               system_prompt: "Are there long words?",
               tools: [],
               user_message: "Input: This does not contain long words."
             } = result
    end
  end
end
