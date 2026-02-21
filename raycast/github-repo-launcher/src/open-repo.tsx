import {
  Action,
  ActionPanel,
  Alert,
  confirmAlert,
  Icon,
  List,
  getFavicon,
} from "@raycast/api";
import { useCachedPromise, useFrecencySorting } from "@raycast/utils";
import { getRepos, removeRepo, type Repo } from "./utils";

export default function OpenRepo() {
  const { data: repos, isLoading, revalidate } = useCachedPromise(getRepos);

  const {
    data: sortedRepos,
    visitItem,
    resetRanking,
  } = useFrecencySorting(repos ?? [], {
    key: (item) => item.id,
  });

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
    <List isLoading={isLoading} searchBarPlaceholder="Search repositories...">
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
    </List>
  );
}
