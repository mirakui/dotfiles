import {
  Action,
  ActionPanel,
  Alert,
  confirmAlert,
  Icon,
  List,
  open,
  showToast,
  Toast,
} from "@raycast/api";
import {
  getFavicon,
  useCachedPromise,
  useFrecencySorting,
} from "@raycast/utils";
import { useState } from "react";
import { addRepo, getRepos, parseGitHubUrl, removeRepo, type Repo } from "./utils";

export default function OpenRepo() {
  const { data: repos, isLoading, revalidate } = useCachedPromise(getRepos);
  const [searchText, setSearchText] = useState("");

  const {
    data: sortedRepos,
    visitItem,
    resetRanking,
  } = useFrecencySorting(repos ?? [], {
    key: (item) => item.id,
  });

  const parsed = searchText ? parseGitHubUrl(searchText) : null;
  const alreadyExists = parsed
    ? sortedRepos.some((r) => r.owner === parsed.owner && r.name === parsed.name)
    : false;

  async function handleAddAndOpen() {
    if (!parsed) return;
    const repo: Repo = {
      id: `${parsed.owner}/${parsed.name}`,
      owner: parsed.owner,
      name: parsed.name,
      url: `https://github.com/${parsed.owner}/${parsed.name}`,
    };
    await addRepo(repo);
    revalidate();
    await open(repo.url);
    await showToast({ style: Toast.Style.Success, title: "Repository added & opened" });
  }

  async function handleRemove(repo: Repo) {
    if (
      await confirmAlert({
        title: "Remove Repository",
        message: `Remove ${repo.owner}/${repo.name} from the list?`,
        primaryAction: {
          title: "Remove",
          style: Alert.ActionStyle.Destructive,
        },
      })
    ) {
      await removeRepo(repo.id);
      revalidate();
    }
  }

  return (
    <List
      isLoading={isLoading}
      filtering
      searchBarPlaceholder="Search or enter owner/repo..."
      onSearchTextChange={setSearchText}
    >
      {sortedRepos.map((repo) => (
        <List.Item
          key={repo.id}
          id={repo.id}
          title={repo.name}
          subtitle={repo.owner}
          icon={getFavicon("https://github.com")}
          actions={
            <ActionPanel>
              <Action.OpenInBrowser
                url={repo.url}
                onOpen={() => visitItem(repo)}
              />
              <Action.CopyToClipboard
                title="Copy URL"
                content={repo.url}
                shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
              />
              <Action.CopyToClipboard
                title="Copy Owner/repo"
                content={`${repo.owner}/${repo.name}`}
                shortcut={{ modifiers: ["cmd", "opt"], key: "c" }}
              />
              <Action
                title="Reset Ranking"
                icon={Icon.ArrowCounterClockwise}
                shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                onAction={() => resetRanking(repo)}
              />
              <Action
                title="Remove from List"
                icon={Icon.Trash}
                style={Action.Style.Destructive}
                shortcut={{ modifiers: ["ctrl"], key: "x" }}
                onAction={() => handleRemove(repo)}
              />
            </ActionPanel>
          }
        />
      ))}
      {parsed && !alreadyExists && (
        <List.Item
          key="__add_and_open__"
          id="__add_and_open__"
          title={`Add & Open ${parsed.owner}/${parsed.name}`}
          icon={Icon.PlusCircle}
          actions={
            <ActionPanel>
              <Action
                title="Add & Open in Browser"
                icon={Icon.Globe}
                onAction={handleAddAndOpen}
              />
            </ActionPanel>
          }
        />
      )}
    </List>
  );
}
