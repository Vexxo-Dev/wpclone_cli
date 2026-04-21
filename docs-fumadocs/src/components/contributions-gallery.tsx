'use client';

import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';

export type ContributionItem = {
  repo: string;
  repoUrl: string;
  imageUrl: string;
  contributions: number;
  lastActivity: string | null;
};

type ContributionsGalleryProps = {
  githubUrl: string;
  items: ContributionItem[];
};

type GitHubProfileResponse = {
  login?: string;
  name?: string | null;
  bio?: string | null;
  location?: string | null;
  followers?: number;
  following?: number;
  blog?: string;
  twitter_username?: string | null;
  html_url?: string;
};

type GitHubSocialAccount = {
  provider: string;
  url: string;
};

type CacheEntry = {
  profile: GitHubProfileResponse;
  social: GitHubSocialAccount[];
};

const profileCache = new Map<string, CacheEntry>();

function formatDate(value: string | null): string {
  if (!value) {
    return 'No recent activity';
  }

  return new Date(value).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function safeExternal(value: string | null | undefined): string | null {
  if (!value) {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  try {
    const normalized = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
    const parsed = new URL(normalized);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

type IconKey = 'github' | 'linkedin' | 'instagram' | 'x' | 'site';

function LinkIcon({ iconKey }: { iconKey: IconKey }) {
  if (iconKey === 'github') {
    return (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <path
          d="M9 18C4 19.5 4 15.5 2 15M16 22V18.13C16.04 17.64 15.98 17.15 15.82 16.69C15.66 16.23 15.39 15.82 15 15.5C18.91 15.06 23 13.58 23 6.98C23 5.29 22.34 3.67 21 2.5C21.64 0.78 21.59 -1.03 21 0C19.45 0 17.91 0.56 16.67 1.5C13.69 0.83 10.31 0.83 7.33 1.5C6.09 0.56 4.55 0 3 0C2.41 -1.03 2.36 0.78 3 2.5C1.66 3.67 1 5.29 1 6.98C1 13.57 5.09 15.06 9 15.5C8.61 15.82 8.34 16.23 8.18 16.69C8.02 17.15 7.96 17.64 8 18.13V22"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }

  if (iconKey === 'linkedin') {
    return (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <path d="M8 11V19" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M12 19V14.6C12 12.8 13.4 11.4 15.2 11.4C17 11.4 18 12.6 18 14.4V19" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <circle cx="8" cy="7.5" r="1.3" fill="currentColor" />
        <rect x="3" y="3" width="18" height="18" rx="3.5" stroke="currentColor" strokeWidth="1.6" />
      </svg>
    );
  }

  if (iconKey === 'instagram') {
    return (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <rect x="3" y="3" width="18" height="18" rx="5" stroke="currentColor" strokeWidth="1.8" />
        <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="1.8" />
        <circle cx="17.5" cy="6.5" r="1" fill="currentColor" />
      </svg>
    );
  }

  if (iconKey === 'x') {
    return (
      <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
        <path d="M4 4L20 20" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        <path d="M20 4L4 20" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.8" />
      <path d="M3 12H21" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M12 3C14.5 5.5 15.9 8.7 15.9 12C15.9 15.3 14.5 18.5 12 21" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M12 3C9.5 5.5 8.1 8.7 8.1 12C8.1 15.3 9.5 18.5 12 21" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

export function ContributionsGallery({ githubUrl, items }: ContributionsGalleryProps) {
  const [open, setOpen] = useState(false);
  const [closingViewAll, setClosingViewAll] = useState(false);
  const [selectedProfile, setSelectedProfile] = useState<ContributionItem | null>(null);
  const [closingProfile, setClosingProfile] = useState(false);
  const [profileData, setProfileData] = useState<GitHubProfileResponse | null>(null);
  const [socialAccounts, setSocialAccounts] = useState<GitHubSocialAccount[]>([]);
  const [profileLoading, setProfileLoading] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const previewItems = useMemo(() => {
    const real = items.slice(0, 6);
    if (real.length >= 5) {
      return real;
    }

    const demoFillers: ContributionItem[] = Array.from({ length: 5 - real.length }, (_, index) => ({
      repo: `demo-${index + 1}`,
      repoUrl: githubUrl,
      imageUrl: `https://avatars.githubusercontent.com/u/${583231 + index * 17}?v=4`,
      contributions: 0,
      lastActivity: null,
    }));

    return [...real, ...demoFillers];
  }, [items, githubUrl]);

  useEffect(() => {
    let active = true;

    async function loadProfile() {
      if (!selectedProfile) {
        setProfileData(null);
        return;
      }

      // Don't load profile for demo profiles
      if (selectedProfile.repo.startsWith('demo-')) {
        setProfileData(null);
        setProfileLoading(false);
        return;
      }

      const cached = profileCache.get(selectedProfile.repo);
      if (cached) {
        setProfileData(cached.profile);
        setSocialAccounts(cached.social);
        setProfileLoading(false);
        return;
      }

      setProfileLoading(true);
      setProfileData(null);

      try {
        const [profileRes, socialRes] = await Promise.all([
          fetch(`https://api.github.com/users/${selectedProfile.repo}`),
          fetch(`https://api.github.com/users/${selectedProfile.repo}/social_accounts`),
        ]);

        const data: GitHubProfileResponse = profileRes.ok ? await profileRes.json() : {};
        const socialData: GitHubSocialAccount[] = socialRes.ok ? await socialRes.json() : [];

        if (active) {
          setProfileData(data);
          setSocialAccounts(socialData);
          profileCache.set(selectedProfile.repo, {
            profile: data,
            social: socialData,
          });
        }
      } catch {
        if (active) {
          setProfileData(null);
          setSocialAccounts([]);
        }
      } finally {
        if (active) {
          setProfileLoading(false);
        }
      }
    }

    void loadProfile();

    return () => {
      active = false;
    };
  }, [selectedProfile]);

  const selectedProfileLinks = useMemo(() => {
    if (!selectedProfile) {
      return [] as Array<{ url: string; iconKey: IconKey; label: string }>;
    }

    const links = new Map<string, { url: string; iconKey: IconKey; label: string }>();

    // Only add GitHub link for the contributor's own profile
    links.set(selectedProfile.repoUrl, {
      url: selectedProfile.repoUrl,
      iconKey: 'github',
      label: 'GitHub',
    });

    // Add social accounts from the fetched data
    socialAccounts.forEach((account) => {
      const url = safeExternal(account.url);
      if (url) {
        let iconKey: IconKey = 'site';
        const provider = account.provider.toLowerCase();

        if (provider.includes('github')) iconKey = 'github';
        else if (provider.includes('linkedin')) iconKey = 'linkedin';
        else if (provider.includes('instagram')) iconKey = 'instagram';
        else if (provider.includes('twitter') || provider.includes('x.com')) iconKey = 'x';

        links.set(url, {
          url,
          iconKey,
          label: account.provider,
        });
      }
    });

    // Add blog/twitter if not already present from social accounts
    const blog = safeExternal(profileData?.blog);
    if (blog) {
      // Basic normalization for comparison
      const normalizedBlog = blog.replace(/\/$/, '');
      const alreadyHasBlog = Array.from(links.keys()).some(k => k.replace(/\/$/, '') === normalizedBlog);
      
      if (!alreadyHasBlog) {
        links.set(blog, {
          url: blog,
          iconKey: 'site',
          label: 'Website',
        });
      }
    }

    if (profileData?.twitter_username) {
      const xUrl = `https://x.com/${profileData.twitter_username}`;
      const safeXUrl = safeExternal(xUrl);
      if (safeXUrl && !links.has(safeXUrl)) {
        links.set(safeXUrl, {
          url: safeXUrl,
          iconKey: 'x',
          label: 'X',
        });
      }
    }

    return [...links.values()];
  }, [selectedProfile, profileData, socialAccounts]);

  const openProfile = (item: ContributionItem) => {
    setSelectedProfile(item);
    setClosingProfile(false);
  };

  const closeProfile = () => {
    setClosingProfile(true);
    setTimeout(() => {
      setSelectedProfile(null);
      setClosingProfile(false);
    }, 200);
  };

  const openViewAll = () => {
    setOpen(true);
    setClosingViewAll(false);
  };

  const closeViewAll = () => {
    setClosingViewAll(true);
    setTimeout(() => {
      setOpen(false);
      setClosingViewAll(false);
    }, 200);
  };

  // View All Modal content
  const viewAllModal = open ? (
    <div
      className={`terminal-modal-overlay ${closingViewAll ? 'is-closing' : ''}`}
      role="dialog"
      aria-modal="true"
      onClick={(e) => {
        if (e.target === e.currentTarget) closeViewAll();
      }}
    >
      <div className="terminal-modal-box terminal-modal-box-main">
        <div className="mb-4 flex items-center justify-between gap-3">
          <p className="terminal-heading text-sm font-semibold">All Contributions</p>
          <button
            type="button"
            className="terminal-contrib-close rounded-md px-2 py-1 text-xs"
            onClick={closeViewAll}
          >
            Close
          </button>
        </div>

        <div className="terminal-modal-content grid gap-2">
          {items.map((item) => (
            <button
              key={item.repo}
              type="button"
              onClick={() => {
                closeViewAll();
                openProfile(item);
              }}
              className="terminal-contrib-row"
            >
              <img src={item.imageUrl} alt={item.repo} className="h-14 w-24 rounded object-cover" loading="lazy" />
              <div className="min-w-0">
                <p className="terminal-card-title truncate text-sm font-semibold">{item.repo}</p>
                <p className="terminal-card-body text-xs">
                  {item.contributions} events • {formatDate(item.lastActivity)}
                </p>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  ) : null;

  // Profile Detail Modal content
  const profileModal = selectedProfile ? (
    <div
      className={`terminal-modal-overlay terminal-modal-overlay-second ${closingProfile ? 'is-closing' : ''}`}
      role="dialog"
      aria-modal="true"
      onClick={(e) => {
        if (e.target === e.currentTarget) closeProfile();
      }}
    >
      <div className="terminal-modal-box terminal-modal-box-profile">
        <div className="mb-3 flex items-center justify-between gap-3">
          <p className="terminal-heading text-sm font-semibold">Profile Details</p>
          <button
            type="button"
            className="terminal-contrib-close rounded-md px-2 py-1 text-xs"
            onClick={closeProfile}
          >
            Close
          </button>
        </div>

        <div className="mb-4 flex items-center gap-4">
          <img
            src={selectedProfile.imageUrl}
            alt={selectedProfile.repo}
            className="h-16 w-16 flex-shrink-0 rounded-full object-cover ring-2 ring-emerald-500/20"
            loading="lazy"
          />
          <div className="min-w-0 flex-1">
            <p className="terminal-card-title break-words text-base font-bold leading-tight">
              {profileData?.name || selectedProfile.repo}
            </p>
            <p className="terminal-card-body text-xs opacity-70">@{selectedProfile.repo}</p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-2">
          <div className="terminal-stat-card rounded-lg px-3 py-2">
            <p className="terminal-stat-label text-[10px] uppercase tracking-wider">Contributions</p>
            <p className="terminal-stat-value text-sm font-semibold">{selectedProfile.contributions}</p>
          </div>
          <div className="terminal-stat-card rounded-lg px-3 py-2">
            <p className="terminal-stat-label text-[10px] uppercase tracking-wider">Followers</p>
            <p className="terminal-stat-value text-sm font-semibold">{profileData?.followers ?? '--'}</p>
          </div>
        </div>

        <p className="terminal-card-body mt-3 text-xs">
          {selectedProfile.repo.startsWith('demo-')
            ? 'Demo profile - contribution placeholder.'
            : profileLoading
              ? 'Loading profile details...'
              : profileData?.bio || 'No bio available for this profile.'}
        </p>

        {profileData?.location ? (
          <p className="terminal-card-body mt-1 text-xs">Location: {profileData.location}</p>
        ) : null}

        <div className="mt-4 border-t border-white/10 pt-3">
          <p className="terminal-stat-label mb-2 text-[11px] uppercase tracking-wider">Social Links</p>
          <div className="flex flex-wrap gap-2">
            {selectedProfileLinks.map((link) => (
              <a
                key={link.url}
                href={link.url}
                target="_blank"
                rel="noreferrer"
                className="terminal-profile-link"
                aria-label={link.label}
                title={link.label}
              >
                <LinkIcon iconKey={link.iconKey} />
              </a>
            ))}
          </div>
        </div>
      </div>
    </div>
  ) : null;

  return (
    <>
      <div className="terminal-contrib-panel mt-4 rounded-2xl p-4">
        <div className="mb-3 flex items-center justify-between gap-2">
          <p className="terminal-stat-label text-[11px] uppercase tracking-wider">Contributions</p>
          <button
            type="button"
            className="terminal-contrib-viewall rounded-md px-2 py-1 text-[11px]"
            onClick={openViewAll}
          >
            View all
          </button>
        </div>

        <div className="flex items-center justify-between gap-3">
          <div className="terminal-contrib-stack">
            {previewItems.map((item, index) => (
              <button
                key={item.repo}
                type="button"
                onClick={() => openProfile(item)}
                className="terminal-contrib-avatar"
                style={{ zIndex: previewItems.length - index }}
                aria-label={`Open ${item.repo} profile`}
                title={`${item.repo} • ${item.contributions} contributions`}
              >
                <img src={item.imageUrl} alt={item.repo} className="h-full w-full object-cover" loading="lazy" />
              </button>
            ))}
          </div>

          <p className="terminal-card-body text-xs">
            {items.length} contributors
          </p>
        </div>
      </div>

      {/* Render modals as portals to escape container and inherit CSS variables */}
      {mounted && viewAllModal && createPortal(
        <div className="landing-shell" style={{ display: 'contents' }}>
          {viewAllModal}
        </div>,
        document.body
      )}
      {mounted && profileModal && createPortal(
        <div className="landing-shell" style={{ display: 'contents' }}>
          {profileModal}
        </div>,
        document.body
      )}
    </>
  );
}