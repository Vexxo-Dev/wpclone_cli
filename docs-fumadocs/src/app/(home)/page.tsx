import Link from 'next/link';
import { ContributionsGallery, type ContributionItem } from '@/components/contributions-gallery';

const GITHUB_REPO = 'Vexxo-Dev/wpclone_cli';

type GitHubRepoResponse = {
  stargazers_count?: number;
  forks_count?: number;
};

type GitHubContributorResponse = {
  login?: string;
  html_url?: string;
  avatar_url?: string;
  contributions?: number;
};

type GitHubRunsResponse = {
  workflow_runs?: Array<{
    conclusion: string | null;
  }>;
};

type LiveStats = {
  stars: number | null;
  forks: number | null;
  migrateSuccessRate: number | null;
};

type ContributionData = {
  githubUrl: string;
  items: ContributionItem[];
};

async function getLiveStats(): Promise<LiveStats> {
  try {
    const [repoRes, runsRes] = await Promise.all([
      fetch(`https://api.github.com/repos/${GITHUB_REPO}`, {
        next: { revalidate: 1800 },
      }),
      fetch(`https://api.github.com/repos/${GITHUB_REPO}/actions/runs?per_page=30`, {
        next: { revalidate: 1800 },
      }),
    ]);

    const repoData: GitHubRepoResponse | null = repoRes.ok ? await repoRes.json() : null;
    const runsData: GitHubRunsResponse | null = runsRes.ok ? await runsRes.json() : null;

    const runs = runsData?.workflow_runs ?? [];
    const completed = runs.filter((run) => run.conclusion !== null);
    const successful = completed.filter((run) => run.conclusion === 'success').length;

    return {
      stars: repoData?.stargazers_count ?? null,
      forks: repoData?.forks_count ?? null,
      migrateSuccessRate: completed.length > 0 ? Math.round((successful / completed.length) * 100) : null,
    };
  } catch {
    return {
      stars: null,
      forks: null,
      migrateSuccessRate: null,
    };
  }
}

function formatNumber(value: number | null): string {
  if (value === null) {
    return '--';
  }

  return new Intl.NumberFormat('en-US').format(value);
}

async function getContributionData(): Promise<ContributionData> {
  const defaultGithubUrl = `https://github.com/${GITHUB_REPO}`;

  try {
    const contributorsRes = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/contributors?per_page=100`, {
      next: { revalidate: 1800 },
    });

    const contributorsData: GitHubContributorResponse[] = contributorsRes.ok ? await contributorsRes.json() : [];

    const items: ContributionItem[] = contributorsData
      .filter((contributor) => contributor.login && contributor.html_url && contributor.avatar_url)
      .map((contributor) => ({
        repo: contributor.login as string,
        repoUrl: contributor.html_url as string,
        imageUrl: contributor.avatar_url as string,
        contributions: contributor.contributions ?? 0,
        lastActivity: null,
      }))
      .sort((a, b) => b.contributions - a.contributions)
      .slice(0, 12);

    if (items.length === 0) {
      items.push({
        repo: GITHUB_REPO,
        repoUrl: defaultGithubUrl,
        imageUrl: `https://opengraph.githubassets.com/1/${GITHUB_REPO}`,
        contributions: 0,
        lastActivity: null,
      });
    }

    return {
      githubUrl: defaultGithubUrl,
      items,
    };
  } catch {
    return {
      githubUrl: defaultGithubUrl,
      items: [
        {
          repo: GITHUB_REPO,
          repoUrl: defaultGithubUrl,
          imageUrl: `https://opengraph.githubassets.com/1/${GITHUB_REPO}`,
          contributions: 0,
          lastActivity: null,
        },
      ],
    };
  }
}

const highlights = [
  {
    title: 'Safe by default',
    description: 'Validate with dry-run before executing a live migration.',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <path d="M12 3L4 6V11C4 16 7.4 20.7 12 22C16.6 20.7 20 16 20 11V6L12 3Z" stroke="currentColor" strokeWidth="1.8" />
      </svg>
    ),
  },
  {
    title: 'Config-first workflow',
    description: 'Reuse one migration.conf across staging and production.',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <path d="M8 4H6A2 2 0 0 0 4 6V8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M16 4H18A2 2 0 0 1 20 6V8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M8 20H6A2 2 0 0 1 4 18V16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M16 20H18A2 2 0 0 0 20 18V16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M8 9H16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M8 13H14" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    title: 'Community support',
    description: 'Open discussions and share migration outcomes with others.',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <path d="M7 9H17" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M7 13H13" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M5 19V6.5C5 5.1 6.1 4 7.5 4H16.5C17.9 4 19 5.1 19 6.5V15.5C19 16.9 17.9 18 16.5 18H8L5 19Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      </svg>
    ),
  },
] as const;

export default async function HomePage() {
  const [stats, contributions] = await Promise.all([getLiveStats(), getContributionData()]);

  return (
    <div className="landing-shell terminal-font relative flex-1 overflow-hidden">
      <div className="pointer-events-none absolute inset-0">
        <div className="terminal-grid-overlay" />
        <div className="terminal-scanline" />
        <div className="terminal-glow terminal-glow-a" />
        <div className="terminal-glow terminal-glow-b" />
      </div>

      <section className="relative mx-auto grid w-full max-w-6xl gap-8 px-6 py-14 md:grid-cols-[1.15fr_0.85fr] md:py-20">
        <div className="terminal-main-panel terminal-reveal rounded-3xl p-7 backdrop-blur-xl md:p-9">
          <p className="terminal-kicker mb-4 text-xs uppercase tracking-[0.28em]">
            WordPress Migration CLI
          </p>

          <h1 className="terminal-heading max-w-3xl text-3xl font-bold leading-tight md:text-5xl">
            wpclone docs_ <span className="terminal-caret">|</span>
          </h1>

          <p className="terminal-body mt-5 max-w-2xl text-sm leading-7 md:text-base">
            Move WordPress projects between servers with a reproducible workflow, built-in
            dry-run validation, and safer defaults for production deployments.
          </p>

          <div className="terminal-command-box terminal-reveal terminal-reveal-delay-1 mt-7 rounded-2xl p-4">
            <p className="terminal-kicker mb-2 text-xs uppercase tracking-[0.2em]">Command Preview</p>
            <pre className="terminal-code overflow-x-auto text-sm">
              <code>$ ./wpclone --config migration.conf --dry-run</code>
            </pre>
          </div>

          <div className="terminal-reveal terminal-reveal-delay-2 mt-7 flex flex-wrap gap-3">
            <Link
              href="/docs"
              className="terminal-primary-btn rounded-xl px-5 py-2.5 text-sm font-semibold transition"
            >
              Open Docs
            </Link>
            <Link
              href="/docs/getting-started"
              className="terminal-secondary-btn rounded-xl px-5 py-2.5 text-sm font-semibold transition"
            >
              Start Here
            </Link>
          </div>
        </div>

        <div className="terminal-side-panel terminal-reveal terminal-reveal-delay-3 rounded-3xl p-5 backdrop-blur-xl">
          <div className="mb-4 flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-rose-400/80" />
            <span className="h-2.5 w-2.5 rounded-full bg-amber-300/80" />
            <span className="h-2.5 w-2.5 rounded-full bg-emerald-300/80" />
            <span className="terminal-kicker ml-2 text-xs">session: wpclone</span>
          </div>

          <div className="terminal-log-box space-y-2 rounded-2xl p-4 text-xs">
            <p className="terminal-log-line terminal-log-delay-1" style={{ '--log-chars': '27ch' } as React.CSSProperties}>
              &gt; Checking source server...
            </p>
            <p className="terminal-log-line terminal-log-delay-2" style={{ '--log-chars': '36ch' } as React.CSSProperties}>
              &gt; Validating SSH + rsync binaries...
            </p>
            <p className="terminal-log-line terminal-log-delay-3" style={{ '--log-chars': '29ch' } as React.CSSProperties}>
              &gt; Dry-run report generated.
            </p>
            <p className="terminal-log-line terminal-log-delay-4" style={{ '--log-chars': '25ch' } as React.CSSProperties}>
              &gt; Ready for execution.
            </p>
          </div>

          <div className="mt-4 grid grid-cols-3 gap-2">
            <div className="terminal-stat-card rounded-xl px-3 py-2">
              <p className="terminal-stat-label text-[11px] uppercase tracking-wider">Forks</p>
              <p className="terminal-stat-value mt-1 text-sm font-semibold">{formatNumber(stats.forks)}</p>
            </div>

            <div className="terminal-stat-card rounded-xl px-3 py-2">
              <p className="terminal-stat-label text-[11px] uppercase tracking-wider">Success Migrate</p>
              <p className="terminal-stat-value mt-1 text-sm font-semibold">
                {stats.migrateSuccessRate === null ? '--' : `${stats.migrateSuccessRate}%`}
              </p>
            </div>

            <div className="terminal-stat-card rounded-xl px-3 py-2">
              <p className="terminal-stat-label text-[11px] uppercase tracking-wider">Stars</p>
              <p className="terminal-stat-value mt-1 text-sm font-semibold">{formatNumber(stats.stars)}</p>
            </div>
          </div>

          <ContributionsGallery
            githubUrl={contributions.githubUrl}
            items={contributions.items}
          />
        </div>
      </section>

      <section className="relative mx-auto w-full max-w-6xl px-6 pb-14 md:pb-20">
        <div className="grid gap-4 md:grid-cols-3">
          {highlights.map((item, index) => (
            <article
              key={item.title}
              className="terminal-highlight-card terminal-reveal rounded-2xl p-5 transition duration-300 hover:-translate-y-0.5"
              style={{ animationDelay: `${0.2 + index * 0.12}s` }}
            >
              <span className="terminal-icon-badge mb-4 inline-flex h-8 w-8 items-center justify-center rounded-lg">
                {item.icon}
              </span>
              <p className="terminal-card-title text-base font-semibold">{item.title}</p>
              <p className="terminal-card-body mt-2 text-sm leading-6">{item.description}</p>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}