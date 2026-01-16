#!/usr/bin/env python3
"""
Find Top Creators by Niche

A focused tool for discovering and ranking top creators within specific niches.

Usage:
    python find_top_creators.py --niches "data analytics,data science"
    python find_top_creators.py --niches "business intelligence" --top 20
    python find_top_creators.py --niches "data engineering" --rising-stars
    python find_top_creators.py --compare "data analytics" "data science" "BI"

Example niches for data professionals:
    - data analytics, data-analytics, analytics
    - data science, data-science, machine learning, ml
    - data engineering, data-engineering, etl, data pipelines
    - business intelligence, bi, tableau, power bi
    - data training, data career, sql tutorials
"""

import argparse
import sys
import json
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent))

from influencer_research.data_loader import DataLoader
from influencer_research.niche_discovery import NicheDiscovery, generate_data_niche_sample_data

try:
    import pandas as pd
    PANDAS_AVAILABLE = True
except ImportError:
    PANDAS_AVAILABLE = False


def print_table(data: list, columns: list = None, max_rows: int = 50):
    """Print data as a formatted table."""
    if not data:
        print("No data to display.")
        return

    if columns is None:
        columns = list(data[0].keys())

    # Calculate column widths
    widths = {}
    for col in columns:
        max_width = len(str(col))
        for row in data[:max_rows]:
            val = row.get(col, '')
            max_width = max(max_width, len(str(val)[:50]))
        widths[col] = min(max_width + 2, 52)

    # Print header
    header = ''.join(str(col)[:widths[col]-2].ljust(widths[col]) for col in columns)
    print(header)
    print('-' * len(header))

    # Print rows
    for row in data[:max_rows]:
        line = ''
        for col in columns:
            val = str(row.get(col, ''))[:widths[col]-2]
            line += val.ljust(widths[col])
        print(line)


def main():
    parser = argparse.ArgumentParser(
        description="Find Top Creators by Niche",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Find top data analytics creators
  python find_top_creators.py --niches "data analytics"

  # Find creators in multiple related niches
  python find_top_creators.py --niches "data analytics,data science,business intelligence"

  # Find rising stars (fast-growing smaller accounts)
  python find_top_creators.py --niches "data engineering" --rising-stars

  # Compare opportunities across niches
  python find_top_creators.py --compare "data analytics" "data science" "machine learning"

  # Filter by follower count
  python find_top_creators.py --niches "data" --min-followers 10000 --max-followers 100000

  # Export to CSV
  python find_top_creators.py --niches "data analytics" --export-csv

Pre-defined niche groups (automatically includes related terms):
  - "data" → data analytics, data science, data engineering, ML, AI, etc.
  - "business-intelligence" → BI, Tableau, Power BI, dashboards, etc.
  - "data-professional" → data career, SQL, Python, training, etc.
  - "marketing" → digital marketing, social media, SEO, growth, etc.
  - "tech" → technology, programming, software, cloud, etc.
        """
    )

    # Niche selection
    parser.add_argument('--niches', '-n', type=str,
                        help='Comma-separated list of niches to search')
    parser.add_argument('--compare', nargs='+',
                        help='Compare multiple niche groups')
    parser.add_argument('--no-related', action='store_true',
                        help='Disable related niche matching (exact match only)')

    # Filters
    parser.add_argument('--min-followers', type=int, default=0,
                        help='Minimum follower count')
    parser.add_argument('--max-followers', type=int, default=float('inf'),
                        help='Maximum follower count')
    parser.add_argument('--min-engagement', type=float, default=0,
                        help='Minimum engagement rate')
    parser.add_argument('--platform', type=str,
                        help='Filter by platform (linkedin, twitter, youtube, tiktok, instagram)')

    # Ranking options
    parser.add_argument('--top', '-t', type=int, default=25,
                        help='Number of top creators to show (default: 25)')
    parser.add_argument('--rank-by', choices=['composite', 'engagement', 'growth', 'followers'],
                        default='composite', help='Ranking method')
    parser.add_argument('--rising-stars', action='store_true',
                        help='Find rising stars (fast-growing smaller accounts)')

    # Data input
    parser.add_argument('--posts', type=str, help='Path to posts CSV')
    parser.add_argument('--creators', type=str, help='Path to creators CSV')
    parser.add_argument('--json', type=str, help='Path to JSON data file')

    # Output
    parser.add_argument('--export-csv', action='store_true',
                        help='Export results to CSV')
    parser.add_argument('--export-json', action='store_true',
                        help='Export results to JSON')
    parser.add_argument('--output-dir', type=str, default='./reports',
                        help='Output directory for exports')
    parser.add_argument('--overview', action='store_true',
                        help='Show niche overview/landscape analysis')

    # Demo mode
    parser.add_argument('--demo', action='store_true',
                        help='Run with sample data for data/analytics niches')
    parser.add_argument('--sample-size', type=int, default=30,
                        help='Number of sample creators to generate')

    args = parser.parse_args()

    # Validate arguments
    if not args.niches and not args.compare and not args.demo:
        parser.print_help()
        print("\nError: Please specify --niches, --compare, or --demo")
        return

    # Load data
    loader = DataLoader()

    if args.posts:
        print(f"Loading posts from: {args.posts}")
        loader.load_posts_from_csv(args.posts)

    if args.creators:
        print(f"Loading creators from: {args.creators}")
        loader.load_creators_from_csv(args.creators)

    if args.json:
        print(f"Loading from JSON: {args.json}")
        loader.load_from_json(args.json)

    # Use sample data if no files provided or demo mode
    if not any([args.posts, args.creators, args.json]) or args.demo:
        print(f"\nGenerating sample data for data/analytics niches ({args.sample_size} creators)...")
        posts, creators = generate_data_niche_sample_data(
            num_creators=args.sample_size,
            posts_per_creator=12
        )
        loader.posts = posts
        loader.creators = creators

        if not args.niches and not args.compare:
            args.niches = "data analytics,data science,data engineering,business intelligence"
            print(f"Using default niches: {args.niches}")

    # Parse niches
    niches = []
    if args.niches:
        niches = [n.strip() for n in args.niches.split(',')]

    # Initialize niche discovery
    discovery = NicheDiscovery(loader.creators, loader.posts)

    print(f"\n{'='*70}")
    print("NICHE CREATOR DISCOVERY")
    print(f"{'='*70}")

    # Handle different modes
    if args.compare:
        # Compare multiple niches
        print(f"\nComparing niches: {', '.join(args.compare)}")
        niche_groups = [[n.strip()] for n in args.compare]
        comparisons = discovery.compare_niches(niche_groups)

        print(f"\n--- NICHE COMPARISON ---")
        print_table(comparisons, [
            'niches', 'total_creators', 'total_reach', 'avg_engagement',
            'avg_growth', 'competition', 'opportunity_score'
        ])

        if args.export_csv and PANDAS_AVAILABLE:
            output_path = Path(args.output_dir)
            output_path.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            df = pd.DataFrame(comparisons)
            df.to_csv(output_path / f"niche_comparison_{timestamp}.csv", index=False)
            print(f"\nExported to: {output_path}/niche_comparison_{timestamp}.csv")

    elif args.overview:
        # Show niche overview
        print(f"\nAnalyzing niche landscape: {', '.join(niches)}")
        overview = discovery.get_niche_overview(niches, include_related=not args.no_related)

        print(f"\n--- NICHE OVERVIEW ---")
        print(f"Total Creators: {overview['total_creators']}")
        print(f"Competition Level: {overview['competition_level']}")

        print(f"\n--- FOLLOWER STATS ---")
        for k, v in overview['follower_stats'].items():
            print(f"  {k}: {v:,}")

        print(f"\n--- ENGAGEMENT STATS ---")
        for k, v in overview['engagement_stats'].items():
            print(f"  {k}: {v}%")

        print(f"\n--- GROWTH STATS ---")
        for k, v in overview['growth_stats'].items():
            print(f"  {k}: {v}")

        print(f"\n--- TIER DISTRIBUTION ---")
        for tier, count in overview['tier_distribution'].items():
            print(f"  {tier}: {count}")

        print(f"\n--- PLATFORM DISTRIBUTION ---")
        for platform, count in overview['platform_distribution'].items():
            print(f"  {platform}: {count}")

    elif args.rising_stars:
        # Find rising stars
        print(f"\nFinding rising stars in: {', '.join(niches)}")
        stars = discovery.find_rising_stars(
            niches,
            min_growth_rate=5.0,
            max_followers=args.max_followers if args.max_followers != float('inf') else 100000,
            top_n=args.top
        )

        print(f"\n--- RISING STARS ({len(stars)} found) ---")
        print("Fast-growing creators with high engagement potential\n")

        print_table(stars, [
            'display_name', 'platform', 'follower_count', 'growth_rate_30d',
            'engagement_rate', 'star_score', 'potential'
        ])

        if args.export_csv and PANDAS_AVAILABLE:
            output_path = Path(args.output_dir)
            output_path.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            niche_slug = niches[0].replace(' ', '-')[:20]
            df = pd.DataFrame(stars)
            df.to_csv(output_path / f"rising_stars_{niche_slug}_{timestamp}.csv", index=False)
            print(f"\nExported to: {output_path}/rising_stars_{niche_slug}_{timestamp}.csv")

    else:
        # Standard ranking
        print(f"\nSearching niches: {', '.join(niches)}")
        print(f"Ranking by: {args.rank_by}")
        print(f"Include related niches: {not args.no_related}")

        # Apply platform filter
        platform_filter = None
        if args.platform:
            from influencer_research.models import Platform
            platform_map = {
                'instagram': Platform.INSTAGRAM,
                'tiktok': Platform.TIKTOK,
                'twitter': Platform.TWITTER,
                'linkedin': Platform.LINKEDIN,
                'youtube': Platform.YOUTUBE,
            }
            if args.platform.lower() in platform_map:
                platform_filter = [platform_map[args.platform.lower()]]

        ranked = discovery.rank_creators_in_niche(
            niches,
            ranking_method=args.rank_by,
            include_related=not args.no_related,
            top_n=args.top,
            min_followers=args.min_followers,
            max_followers=args.max_followers,
            min_engagement_rate=args.min_engagement,
            platforms=platform_filter
        )

        if not ranked:
            print("\nNo creators found matching the criteria.")
            return

        print(f"\n--- TOP {len(ranked)} CREATORS ---\n")

        # Show compact table
        print_table(ranked, [
            'display_name', 'platform', 'tier', 'follower_count',
            'avg_engagement_rate', 'growth_rate_30d', 'composite_score', 'recommendation'
        ])

        # Show detailed view of top 5
        print(f"\n--- DETAILED VIEW (Top 5) ---")
        for i, creator in enumerate(ranked[:5], 1):
            print(f"\n{i}. {creator['display_name']} (@{creator['username']})")
            print(f"   Platform: {creator['platform']} | Tier: {creator['tier']}")
            print(f"   Followers: {creator['follower_count']:,}")
            print(f"   Niches: {creator['all_niches']}")
            print(f"   Engagement Rate: {creator['avg_engagement_rate']}%")
            print(f"   30-Day Growth: {creator['growth_rate_30d']}%")
            print(f"   Scores: Engagement={creator['engagement_score']}, Growth={creator['growth_score']}, Relevance={creator['relevance_score']}")
            print(f"   COMPOSITE SCORE: {creator['composite_score']}")
            print(f"   → {creator['recommendation']}")

        # Export if requested
        if args.export_csv and PANDAS_AVAILABLE:
            output_path = Path(args.output_dir)
            output_path.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            niche_slug = niches[0].replace(' ', '-')[:20]
            df = pd.DataFrame(ranked)
            filename = f"top_creators_{niche_slug}_{timestamp}.csv"
            df.to_csv(output_path / filename, index=False)
            print(f"\nExported to: {output_path}/{filename}")

        if args.export_json:
            output_path = Path(args.output_dir)
            output_path.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            niche_slug = niches[0].replace(' ', '-')[:20]
            filename = f"top_creators_{niche_slug}_{timestamp}.json"
            with open(output_path / filename, 'w') as f:
                json.dump(ranked, f, indent=2)
            print(f"\nExported to: {output_path}/{filename}")

    print(f"\n{'='*70}")
    print("Analysis complete!")


if __name__ == "__main__":
    main()
