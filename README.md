# Influencer & Content Market Research Tool

A comprehensive Python solution for tracking engagement metrics, trending topics, top voices by niche, and identifying content patterns for actionable marketing decisions.

## Features

### Data Capture

**Post-Level Data:**
- Timestamp, text/media type
- Hashtags and links
- Topic classification
- Engagement metrics (likes, comments, reposts, saves, views)
- Engagement velocity (how fast posts gain reactions)

**Creator-Level Data:**
- Follower count and growth rate
- Average engagement rate
- Niche tags and classifications
- Content consistency scores

**Engagement Quality:**
- Comment sentiment analysis
- Repeated commenter detection (community indicators)
- Expert/authority commenter identification
- Authenticity scoring (bot detection)

### Key Analytics

1. **Engagement Rate + Velocity Analysis**
   - Tracks engagement rate (quality) over raw likes (quantity)
   - Measures engagement velocity (viral potential)
   - Identifies save rate (content value indicator)

2. **Content Taxonomy & Pattern Detection**
   - Classifies content by hook type (question, listicle, how-to, controversial, etc.)
   - Identifies content formats that perform best
   - Discovers "repeatable formulas" that consistently drive engagement

3. **Whitespace Analysis**
   - Identifies high-demand topics with low creator saturation
   - Scores opportunities by demand/supply ratio
   - Suggests content angles for underserved niches

4. **Collaboration Targeting**
   - Prioritizes niche alignment over follower count
   - Scores engagement quality and authenticity
   - Identifies micro/mid-tier creators with high potential

## Quick Start

### Installation

```bash
# Clone or download the project
cd In_Marketing

# Install dependencies
pip install -r requirements.txt
```

### Run with Sample Data (Demo)

```bash
# Run with auto-generated sample data
python run_research.py

# Generate more sample data
python run_research.py --sample-size 50
```

### Run with Your Own Data

```bash
# Create CSV templates to fill in
python run_research.py --create-templates

# Then load your data
python run_research.py --posts sample_data/sample_posts.csv --creators sample_data/sample_creators.csv

# Export actionable reports
python run_research.py --posts your_posts.csv --creators your_creators.csv --export-csv
python run_research.py --posts your_posts.csv --creators your_creators.csv --export-excel
```

### Set Target Niches for Collaboration Analysis

```bash
python run_research.py --niches "ai,marketing,productivity" --export-csv
```

## Data Input Formats

### Posts CSV

Required columns:
- `post_id` or `id`
- `creator_id` or `author_id`
- `text` or `content` or `caption`
- `timestamp` or `date` or `created_at`

Optional columns:
- `likes`, `comments`, `shares`, `saves`, `views`
- `hashtags` (comma-separated)
- `topics` (comma-separated)
- `media_type` (text, image, video, reel, carousel, etc.)
- `platform` (instagram, tiktok, twitter, linkedin, youtube)
- `engagements_1h`, `engagements_6h`, `engagements_24h` (for velocity tracking)

### Creators CSV

Required columns:
- `creator_id` or `id`
- `username` or `handle`

Optional columns:
- `display_name` or `name`
- `follower_count` or `followers`
- `following_count`
- `bio` or `description`
- `niche_tags` or `niches` (comma-separated)
- `avg_engagement_rate` or `engagement_rate`
- `growth_rate_7d`, `growth_rate_30d`
- `platform`

## Output Reports

### 1. Executive Summary (`executive_summary.json`)
High-level overview with key metrics and recommendations.

### 2. Creator Rankings (`creator_rankings.csv`)
Creators ranked by composite score combining:
- Engagement rate (quality)
- Growth rate (momentum)
- Authenticity (real engagement)
- Community score (loyal followers)

### 3. Content Ideas (`content_ideas.csv`)
Actionable content templates based on:
- Winning content formulas
- Whitespace opportunities
- Suggested hooks and formats

### 4. Collaboration Targets (`collaboration_targets.csv`)
Potential partners ranked by:
- Niche alignment score
- Engagement quality
- Growth trajectory

### 5. Trending Topics (`trending_topics.csv`)
Topics gaining momentum with growth rates.

### 6. Top Hashtags (`top_hashtags.csv`)
Hashtags ranked by average engagement.

## Key Insights & Recommendations

### Why Engagement Rate > Raw Likes
- A micro-influencer with 5% engagement beats a mega-influencer with 0.5%
- Higher engagement = more algorithm favor and organic reach
- Niche audiences convert better than mass audiences

### Why Velocity Matters
- Fast early engagement signals viral potential
- Algorithms prioritize high-velocity content
- Track engagements at 1h, 6h, 24h intervals

### Whitespace = Opportunity
- High-demand topics with few creators = low competition
- Early movers establish authority
- Use suggested content angles to enter new niches

### Quality > Quantity for Collaborations
- Niche alignment matters more than follower count
- Authentic engagement indicates real audience
- Growing creators offer better ROI than stagnant large accounts

## Data Collection Notes

### API/ToS Compliance

This tool processes data you provide - it does not scrape platforms directly.

**Recommended data sources:**
1. **Official APIs** (Instagram Graph API, TikTok API, Twitter API)
2. **Platform exports** (Creator Studio, Analytics dashboards)
3. **Third-party tools** (Hootsuite, Sprout Social, Later)
4. **Manual collection** (copy data to CSV)

**Watch-outs:**
- Respect platform Terms of Service
- Use official APIs where available
- Don't scrape without authorization
- Rate limit your API calls

### Data Quality Tips
- Track the same creators over time for growth metrics
- Capture engagement at multiple time points for velocity
- Include comment data for quality analysis
- Tag content with topics/niches for better analysis

## Architecture

```
influencer_research/
├── __init__.py          # Package exports
├── models.py            # Data models (Post, Creator, etc.)
├── data_loader.py       # CSV/JSON/Excel data loading
├── analytics.py         # Engagement, trend, pattern analysis
├── sentiment.py         # Comment quality analysis
├── reporting.py         # Report generation
└── sample_data.py       # Sample data generation
```

## License

MIT License - Use freely for your marketing research needs.
