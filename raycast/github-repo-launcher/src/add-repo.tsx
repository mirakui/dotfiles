import {
  Action,
  ActionPanel,
  Form,
  popToRoot,
  showToast,
  Toast,
} from "@raycast/api";
import { useForm, FormValidation } from "@raycast/utils";
import { addRepo, parseGitHubUrl } from "./utils";

interface FormValues {
  input: string;
}

export default function AddRepo() {
  const { handleSubmit, itemProps } = useForm<FormValues>({
    async onSubmit(values) {
      const parsed = parseGitHubUrl(values.input);
      if (!parsed) {
        await showToast({ style: Toast.Style.Failure, title: "Invalid input" });
        return;
      }

      await addRepo({
        id: `${parsed.owner}/${parsed.name}`,
        owner: parsed.owner,
        name: parsed.name,
        url: `https://github.com/${parsed.owner}/${parsed.name}`,
      });

      await showToast({
        style: Toast.Style.Success,
        title: "Repository added",
      });
      popToRoot();
    },
    validation: {
      input: FormValidation.Required,
    },
  });

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Add Repository" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField
        title="Repository"
        placeholder="owner/repo or https://github.com/owner/repo"
        {...itemProps.input}
      />
    </Form>
  );
}
