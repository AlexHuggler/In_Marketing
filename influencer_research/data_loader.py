"""
Data Loader Module

Handles importing data from various sources:
- CSV/Excel files
- JSON exports
- API integrations (with rate limiting and ToS compliance)
- Manual data entry
"""

import csv
import json
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
import pandas as pd

from .models import (
    Post, Creator, Comment, EngagementMetrics,
    Platform, MediaType, ContentHook, ContentFormat,
    CreatorGrowthMetrics
)


class DataLoader:
    """
    Unified data loader for influencer research.

    Supports multiple data sources while respecting API/ToS constraints.
    For platforms with strict scraping rules, use official APIs or
    manual data export features.
    """

    PLATFORM_MAP = {
        'instagram': Platform.INSTAGRAM,
        'tiktok': Platform.TIKTOK,
        'twitter': Platform.TWITTER,
        'x': Platform.TWITTER,
        'linkedin': Platform.LINKEDIN,
        'youtube': Platform.YOUTUBE,
        'facebook': Platform.FACEBOOK,
        'threads': Platform.THREADS,
    }

    MEDIA_TYPE_MAP = {
        'text': MediaType.TEXT,
        'image': MediaType.IMAGE,
        'photo': MediaType.IMAGE,
        'video': MediaType.VIDEO,
        'carousel': MediaType.CAROUSEL,
        'story': MediaType.STORY,
        'reel': MediaType.REEL,
        'reels': MediaType.REEL,
        'live': MediaType.LIVE,
        'article': MediaType.ARTICLE,
        'thread': MediaType.THREAD,
    }

    def __init__(self):
        self.posts: List[Post] = []
        self.creators: Dict[str, Creator] = {}
        self.load_errors: List[str] = []

    def load_posts_from_csv(self, filepath: str, platform: Optional[Platform] = None) -> List[Post]:
        """
        Load posts from a CSV file.

        Expected columns (flexible naming):
        - post_id or id
        - creator_id or author_id or user_id
        - text or content or caption
        - timestamp or date or created_at
        - likes, comments, shares, saves, views (engagement metrics)
        - hashtags (comma or space separated)
        - media_type or type
        - platform (if not specified)
        """
        posts = []
        df = pd.read_csv(filepath)

        # Normalize column names
        df.columns = df.columns.str.lower().str.strip().str.replace(' ', '_')

        for _, row in df.iterrows():
            try:
                post = self._parse_post_row(row, platform)
                if post:
                    posts.append(post)
                    self.posts.append(post)
            except Exception as e:
                self.load_errors.append(f"Error parsing row: {e}")

        return posts

    def load_creators_from_csv(self, filepath: str, platform: Optional[Platform] = None) -> List[Creator]:
        """
        Load creators from a CSV file.

        Expected columns:
        - creator_id or id or user_id
        - username or handle
        - display_name or name
        - follower_count or followers
        - following_count or following
        - niche_tags or niches or niche
        - bio or description
        - engagement_rate or avg_engagement
        """
        creators = []
        df = pd.read_csv(filepath)
        df.columns = df.columns.str.lower().str.strip().str.replace(' ', '_')

        for _, row in df.iterrows():
            try:
                creator = self._parse_creator_row(row, platform)
                if creator:
                    creators.append(creator)
                    self.creators[creator.creator_id] = creator
            except Exception as e:
                self.load_errors.append(f"Error parsing creator row: {e}")

        return creators

    def load_from_json(self, filepath: str) -> Tuple[List[Post], List[Creator]]:
        """
        Load data from a JSON export file.

        Expected format:
        {
            "posts": [...],
            "creators": [...],
            "metadata": {...}
        }
        """
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)

        posts = []
        creators = []

        if 'posts' in data:
            for post_data in data['posts']:
                post = self._parse_post_dict(post_data)
                if post:
                    posts.append(post)
                    self.posts.append(post)

        if 'creators' in data:
            for creator_data in data['creators']:
                creator = self._parse_creator_dict(creator_data)
                if creator:
                    creators.append(creator)
                    self.creators[creator.creator_id] = creator

        return posts, creators

    def load_from_excel(self, filepath: str, sheet_name: str = None) -> Tuple[List[Post], List[Creator]]:
        """Load data from Excel file with separate sheets for posts and creators."""
        posts = []
        creators = []

        excel_file = pd.ExcelFile(filepath)

        if 'posts' in excel_file.sheet_names or sheet_name == 'posts':
            df = pd.read_excel(filepath, sheet_name='posts' if sheet_name is None else sheet_name)
            df.columns = df.columns.str.lower().str.strip().str.replace(' ', '_')
            for _, row in df.iterrows():
                post = self._parse_post_row(row)
                if post:
                    posts.append(post)
                    self.posts.append(post)

        if 'creators' in excel_file.sheet_names:
            df = pd.read_excel(filepath, sheet_name='creators')
            df.columns = df.columns.str.lower().str.strip().str.replace(' ', '_')
            for _, row in df.iterrows():
                creator = self._parse_creator_row(row)
                if creator:
                    creators.append(creator)
                    self.creators[creator.creator_id] = creator

        return posts, creators

    def _parse_post_row(self, row: pd.Series, platform: Optional[Platform] = None) -> Optional[Post]:
        """Parse a single post row from DataFrame."""
        # Get post ID
        post_id = str(self._get_value(row, ['post_id', 'id', 'content_id']) or '')
        if not post_id:
            return None

        # Get creator ID
        creator_id = str(self._get_value(row, ['creator_id', 'author_id', 'user_id', 'account_id']) or '')

        # Get platform
        if platform is None:
            platform_str = str(self._get_value(row, ['platform', 'network', 'source']) or 'other').lower()
            platform = self.PLATFORM_MAP.get(platform_str, Platform.OTHER)

        # Get text content
        text = str(self._get_value(row, ['text', 'content', 'caption', 'body', 'message']) or '')

        # Get timestamp
        timestamp_val = self._get_value(row, ['timestamp', 'date', 'created_at', 'posted_at', 'published_at'])
        timestamp = self._parse_timestamp(timestamp_val)

        # Get media type
        media_type_str = str(self._get_value(row, ['media_type', 'type', 'content_type', 'format']) or 'text').lower()
        media_type = self.MEDIA_TYPE_MAP.get(media_type_str, MediaType.TEXT)

        # Get hashtags
        hashtags_val = self._get_value(row, ['hashtags', 'tags', 'hash_tags'])
        hashtags = self._parse_list(hashtags_val)

        # Get topics/niches
        topics_val = self._get_value(row, ['topics', 'categories', 'topic'])
        topics = self._parse_list(topics_val)

        # Get engagement metrics
        metrics = EngagementMetrics(
            likes=int(self._get_value(row, ['likes', 'like_count', 'hearts', 'reactions']) or 0),
            comments=int(self._get_value(row, ['comments', 'comment_count', 'replies']) or 0),
            shares=int(self._get_value(row, ['shares', 'share_count', 'reposts', 'retweets', 'reblogs']) or 0),
            saves=int(self._get_value(row, ['saves', 'save_count', 'bookmarks', 'bookmark_count']) or 0),
            views=int(self._get_value(row, ['views', 'view_count', 'impressions', 'plays']) or 0),
            reach=int(self._get_value(row, ['reach', 'unique_views']) or 0),
        )

        # Get velocity metrics if available
        engagements_1h = int(self._get_value(row, ['engagements_1h', 'eng_1h']) or 0)
        engagements_6h = int(self._get_value(row, ['engagements_6h', 'eng_6h']) or 0)
        engagements_24h = int(self._get_value(row, ['engagements_24h', 'eng_24h']) or 0)

        # Get URL
        url = str(self._get_value(row, ['url', 'link', 'post_url', 'permalink']) or '')

        return Post(
            post_id=post_id,
            creator_id=creator_id,
            platform=platform,
            text=text,
            media_type=media_type,
            timestamp=timestamp,
            hashtags=hashtags,
            topics=topics,
            metrics=metrics,
            url=url,
            engagements_1h=engagements_1h,
            engagements_6h=engagements_6h,
            engagements_24h=engagements_24h,
        )

    def _parse_creator_row(self, row: pd.Series, platform: Optional[Platform] = None) -> Optional[Creator]:
        """Parse a single creator row from DataFrame."""
        # Get creator ID
        creator_id = str(self._get_value(row, ['creator_id', 'id', 'user_id', 'account_id']) or '')
        if not creator_id:
            return None

        # Get username
        username = str(self._get_value(row, ['username', 'handle', 'screen_name', 'user_name']) or '')

        # Get platform
        if platform is None:
            platform_str = str(self._get_value(row, ['platform', 'network', 'source']) or 'other').lower()
            platform = self.PLATFORM_MAP.get(platform_str, Platform.OTHER)

        # Get display name
        display_name = str(self._get_value(row, ['display_name', 'name', 'full_name']) or username)

        # Get bio
        bio = str(self._get_value(row, ['bio', 'description', 'about']) or '')

        # Get follower metrics
        follower_count = int(self._get_value(row, ['follower_count', 'followers', 'subscriber_count', 'subscribers']) or 0)
        following_count = int(self._get_value(row, ['following_count', 'following']) or 0)

        # Get niche tags
        niche_val = self._get_value(row, ['niche_tags', 'niches', 'niche', 'categories', 'category'])
        niche_tags = self._parse_list(niche_val)
        primary_niche = niche_tags[0] if niche_tags else ''

        # Get engagement metrics
        avg_engagement_rate = float(self._get_value(row, ['avg_engagement_rate', 'engagement_rate', 'avg_engagement']) or 0)
        avg_likes = float(self._get_value(row, ['avg_likes', 'average_likes']) or 0)
        avg_comments = float(self._get_value(row, ['avg_comments', 'average_comments']) or 0)

        # Get growth metrics
        growth_7d = float(self._get_value(row, ['growth_rate_7d', 'weekly_growth', 'follower_growth_7d']) or 0)
        growth_30d = float(self._get_value(row, ['growth_rate_30d', 'monthly_growth', 'follower_growth_30d']) or 0)

        # Get total posts
        total_posts = int(self._get_value(row, ['total_posts', 'post_count', 'posts']) or 0)

        return Creator(
            creator_id=creator_id,
            username=username,
            platform=platform,
            display_name=display_name,
            bio=bio,
            follower_count=follower_count,
            following_count=following_count,
            niche_tags=niche_tags,
            primary_niche=primary_niche,
            avg_engagement_rate=avg_engagement_rate,
            avg_likes=avg_likes,
            avg_comments=avg_comments,
            total_posts=total_posts,
            follower_growth_rate_7d=growth_7d,
            follower_growth_rate_30d=growth_30d,
            last_updated=datetime.now(),
        )

    def _parse_post_dict(self, data: Dict[str, Any]) -> Optional[Post]:
        """Parse a post from a dictionary."""
        row = pd.Series(data)
        return self._parse_post_row(row)

    def _parse_creator_dict(self, data: Dict[str, Any]) -> Optional[Creator]:
        """Parse a creator from a dictionary."""
        row = pd.Series(data)
        return self._parse_creator_row(row)

    def _get_value(self, row: pd.Series, possible_keys: List[str]) -> Any:
        """Get value from row using multiple possible column names."""
        for key in possible_keys:
            if key in row.index and pd.notna(row[key]):
                return row[key]
        return None

    def _parse_timestamp(self, value: Any) -> datetime:
        """Parse timestamp from various formats."""
        if value is None:
            return datetime.now()

        if isinstance(value, datetime):
            return value

        if isinstance(value, pd.Timestamp):
            return value.to_pydatetime()

        if isinstance(value, str):
            # Try common formats
            formats = [
                '%Y-%m-%d %H:%M:%S',
                '%Y-%m-%dT%H:%M:%S',
                '%Y-%m-%dT%H:%M:%SZ',
                '%Y-%m-%d',
                '%m/%d/%Y %H:%M:%S',
                '%m/%d/%Y',
                '%d/%m/%Y',
            ]
            for fmt in formats:
                try:
                    return datetime.strptime(value, fmt)
                except ValueError:
                    continue

        return datetime.now()

    def _parse_list(self, value: Any) -> List[str]:
        """Parse a list from various formats."""
        if value is None or (isinstance(value, float) and pd.isna(value)):
            return []

        if isinstance(value, list):
            return [str(v).strip() for v in value if v]

        if isinstance(value, str):
            # Handle comma, semicolon, or space separated
            if ',' in value:
                return [v.strip() for v in value.split(',') if v.strip()]
            elif ';' in value:
                return [v.strip() for v in value.split(';') if v.strip()]
            elif ' ' in value and '#' in value:
                # Hashtag format
                return [v.strip() for v in value.split() if v.strip()]
            else:
                return [value.strip()] if value.strip() else []

        return []

    def link_posts_to_creators(self):
        """Link loaded posts to their respective creators."""
        for post in self.posts:
            if post.creator_id in self.creators:
                self.creators[post.creator_id].posts.append(post)

    def get_all_posts(self) -> List[Post]:
        """Return all loaded posts."""
        return self.posts

    def get_all_creators(self) -> Dict[str, Creator]:
        """Return all loaded creators."""
        return self.creators

    def get_posts_by_platform(self, platform: Platform) -> List[Post]:
        """Filter posts by platform."""
        return [p for p in self.posts if p.platform == platform]

    def get_creators_by_niche(self, niche: str) -> List[Creator]:
        """Filter creators by niche tag."""
        niche_lower = niche.lower()
        return [
            c for c in self.creators.values()
            if niche_lower in [n.lower() for n in c.niche_tags]
        ]

    def export_to_json(self, filepath: str):
        """Export all loaded data to JSON."""
        data = {
            'posts': [self._post_to_dict(p) for p in self.posts],
            'creators': [self._creator_to_dict(c) for c in self.creators.values()],
            'metadata': {
                'exported_at': datetime.now().isoformat(),
                'total_posts': len(self.posts),
                'total_creators': len(self.creators),
            }
        }

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, default=str)

    def _post_to_dict(self, post: Post) -> Dict[str, Any]:
        """Convert post to dictionary."""
        return {
            'post_id': post.post_id,
            'creator_id': post.creator_id,
            'platform': post.platform.value,
            'text': post.text,
            'media_type': post.media_type.value,
            'timestamp': post.timestamp.isoformat(),
            'hashtags': post.hashtags,
            'topics': post.topics,
            'url': post.url,
            'metrics': {
                'likes': post.metrics.likes,
                'comments': post.metrics.comments,
                'shares': post.metrics.shares,
                'saves': post.metrics.saves,
                'views': post.metrics.views,
                'engagement_rate': post.metrics.engagement_rate,
            }
        }

    def _creator_to_dict(self, creator: Creator) -> Dict[str, Any]:
        """Convert creator to dictionary."""
        return {
            'creator_id': creator.creator_id,
            'username': creator.username,
            'platform': creator.platform.value,
            'display_name': creator.display_name,
            'follower_count': creator.follower_count,
            'niche_tags': creator.niche_tags,
            'primary_niche': creator.primary_niche,
            'avg_engagement_rate': creator.avg_engagement_rate,
            'follower_growth_rate_7d': creator.follower_growth_rate_7d,
            'follower_growth_rate_30d': creator.follower_growth_rate_30d,
        }


def create_sample_data_templates():
    """Create sample CSV templates for data input."""
    # Posts template
    posts_template = """post_id,creator_id,platform,text,media_type,timestamp,likes,comments,shares,saves,views,hashtags,topics
p001,c001,instagram,"Check out this amazing productivity hack! #productivity #lifehacks",image,2024-01-15 10:30:00,1500,89,45,230,15000,"productivity,lifehacks","productivity,self-improvement"
p002,c001,instagram,"Morning routine that changed my life",reel,2024-01-16 08:00:00,5200,312,178,890,52000,"morningroutine,wellness","wellness,lifestyle"
p003,c002,tiktok,"Hot take: AI will replace most jobs in 5 years",video,2024-01-15 14:00:00,28000,1450,2100,3200,280000,"ai,future,tech","technology,opinion"
"""

    # Creators template
    creators_template = """creator_id,username,platform,display_name,follower_count,following_count,bio,niche_tags,avg_engagement_rate,growth_rate_7d,growth_rate_30d,total_posts
c001,productivity_pro,instagram,Sarah Johnson,45000,890,"Helping you work smarter not harder","productivity,self-improvement,business",3.8,1.2,4.5,342
c002,tech_insider,tiktok,Mike Chen,890000,156,"Breaking down tech trends for everyone","technology,ai,future,startups",4.2,2.8,12.3,567
c003,wellness_guru,instagram,Emma Williams,125000,445,"Holistic health & mindful living","wellness,health,mindfulness,lifestyle",5.1,0.9,3.2,890
"""

    return posts_template, creators_template
