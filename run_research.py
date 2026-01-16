#!/usr/bin/env python3
"""
Influencer & Content Market Research Tool

Main entry point for running influencer research analysis.

Usage:
    python run_research.py                     # Run with sample data
    python run_research.py --posts data.csv   # Load posts from CSV
    python run_research.py --help             # Show all options

This tool generates actionable insights for:
- Top creators by engagement (quality over quantity)
- Trending topics and hashtags
- Winning content formulas (repeatable patterns)
- Whitespace opportunities (underserved niches)
- Collaboration targets (niche-aligned partners)
"""

import argparse
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from influencer_research.data_loader import DataLoader
from influencer_research.reporting import ReportGenerator
from influencer_research.sample_data import generate_sample_data, create_sample_csv_files


def main():
    parser = argparse.ArgumentParser(
        description="Influencer & Content Market Research Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run_research.py                           # Demo with sample data
  python run_research.py --posts posts.csv         # Analyze posts from CSV
  python run_research.py --posts posts.csv --creators creators.csv
  python run_research.py --niches "ai,marketing"   # Set target niches
  python run_research.py --export-csv              # Export reports to CSV
  python run_research.py --export-excel            # Export to Excel workbook

Data Format:
  Posts CSV columns: post_id, creator_id, platform, text, media_type,
                     timestamp, likes, comments, shares, saves, views,
                     hashtags, topics

  Creators CSV columns: creator_id, username, platform, display_name,
                        follower_count, niche_tags, avg_engagement_rate,
                        growth_rate_7d, growth_rate_30d
        """
    )

    # Data input options
    parser.add_argument('--posts', type=str, help='Path to posts CSV file')
    parser.add_argument('--creators', type=str, help='Path to creators CSV file')
    parser.add_argument('--json', type=str, help='Path to JSON data file')
    parser.add_argument('--excel', type=str, help='Path to Excel workbook')

    # Analysis options
    parser.add_argument('--niches', type=str,
                        help='Target niches for analysis (comma-separated)')
    parser.add_argument('--platform', type=str,
                        help='Filter by platform (instagram, tiktok, twitter, linkedin)')

    # Output options
    parser.add_argument('--export-csv', action='store_true',
                        help='Export reports to CSV files')
    parser.add_argument('--export-excel', action='store_true',
                        help='Export reports to Excel workbook')
    parser.add_argument('--output-dir', type=str, default='./reports',
                        help='Output directory for exports (default: ./reports)')
    parser.add_argument('--quiet', '-q', action='store_true',
                        help='Suppress console output')

    # Sample data options
    parser.add_argument('--create-templates', action='store_true',
                        help='Create sample CSV templates')
    parser.add_argument('--sample-size', type=int, default=25,
                        help='Number of creators for sample data (default: 25)')

    args = parser.parse_args()

    # Create sample templates if requested
    if args.create_templates:
        create_sample_csv_files()
        print("\nSample CSV templates created!")
        print("Edit these files with your data, then run:")
        print("  python run_research.py --posts sample_data/sample_posts.csv --creators sample_data/sample_creators.csv")
        return

    # Load data
    loader = DataLoader()
    target_niches = args.niches.split(',') if args.niches else []

    if args.posts:
        print(f"Loading posts from: {args.posts}")
        loader.load_posts_from_csv(args.posts)

    if args.creators:
        print(f"Loading creators from: {args.creators}")
        loader.load_creators_from_csv(args.creators)

    if args.json:
        print(f"Loading data from JSON: {args.json}")
        loader.load_from_json(args.json)

    if args.excel:
        print(f"Loading data from Excel: {args.excel}")
        loader.load_from_excel(args.excel)

    # If no data files provided, use sample data
    if not any([args.posts, args.creators, args.json, args.excel]):
        print("\nNo data files provided. Generating sample data for demonstration...")
        print(f"Creating {args.sample_size} sample creators with posts...\n")

        posts, creators = generate_sample_data(
            num_creators=args.sample_size,
            posts_per_creator=15,
            comments_per_post=10
        )

        loader.posts = posts
        loader.creators = creators

        if not target_niches:
            # Default niches for sample data
            target_niches = ['productivity', 'ai', 'marketing']

    # Link posts to creators
    loader.link_posts_to_creators()

    # Report any loading errors
    if loader.load_errors:
        print(f"\nWarning: {len(loader.load_errors)} errors during data loading:")
        for error in loader.load_errors[:5]:
            print(f"  - {error}")
        if len(loader.load_errors) > 5:
            print(f"  ... and {len(loader.load_errors) - 5} more")

    # Show data summary
    print(f"\n{'='*60}")
    print("DATA LOADED")
    print(f"{'='*60}")
    print(f"Total posts: {len(loader.posts)}")
    print(f"Total creators: {len(loader.creators)}")
    if target_niches:
        print(f"Target niches: {', '.join(target_niches)}")

    # Generate reports
    print(f"\n{'='*60}")
    print("GENERATING ANALYSIS...")
    print(f"{'='*60}")

    report_gen = ReportGenerator(
        posts=loader.posts,
        creators=loader.creators,
        target_niches=target_niches
    )

    # Print summary to console (unless quiet mode)
    if not args.quiet:
        report_gen.print_summary()

    # Export reports
    if args.export_csv:
        print(f"\nExporting CSV reports to: {args.output_dir}")
        report_gen.export_to_csv(args.output_dir)

    if args.export_excel:
        excel_path = f"{args.output_dir}/influencer_research.xlsx"
        print(f"\nExporting Excel workbook to: {excel_path}")
        report_gen.export_to_excel(excel_path)

    # Always show how to export if not exporting
    if not args.export_csv and not args.export_excel:
        print("\n" + "="*60)
        print("EXPORT OPTIONS")
        print("="*60)
        print("To export actionable reports, run:")
        print(f"  python run_research.py --export-csv")
        print(f"  python run_research.py --export-excel")
        print("\nTo create data templates for your own data:")
        print(f"  python run_research.py --create-templates")

    print("\nAnalysis complete!")


if __name__ == "__main__":
    main()
