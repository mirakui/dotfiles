import { LocalStorage } from "@raycast/api";

export interface Repo {
  id: string;
  name: string;
  owner: string;
  url: string;
}

const STORAGE_KEY = "repos";

export async function getRepos(): Promise<Repo[]> {
  const json = await LocalStorage.getItem<string>(STORAGE_KEY);
  if (!json) return [];
  return JSON.parse(json) as Repo[];
}

export async function saveRepos(repos: Repo[]): Promise<void> {
  await LocalStorage.setItem(STORAGE_KEY, JSON.stringify(repos));
}

export async function addRepo(repo: Repo): Promise<void> {
  const repos = await getRepos();
  if (repos.some((r) => r.id === repo.id)) return;
  repos.push(repo);
  await saveRepos(repos);
}

export async function removeRepo(id: string): Promise<void> {
  const repos = await getRepos();
  await saveRepos(repos.filter((r) => r.id !== id));
}

export function parseGitHubUrl(
  input: string,
): { owner: string; name: string } | null {
  const trimmed = input.trim().replace(/\/+$/, "");

  // https://github.com/owner/repo or github.com/owner/repo
  const urlMatch = trimmed.match(
    /^(?:https?:\/\/)?github\.com\/([^/]+)\/([^/]+)/,
  );
  if (urlMatch) {
    return { owner: urlMatch[1], name: urlMatch[2] };
  }

  // owner/repo
  const shortMatch = trimmed.match(/^([^/\s]+)\/([^/\s]+)$/);
  if (shortMatch) {
    return { owner: shortMatch[1], name: shortMatch[2] };
  }

  return null;
}
