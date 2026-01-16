"""
Data Models for Influencer Research

Defines core data structures for tracking posts, creators, and engagement metrics.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum


class MediaType(Enum):
    """Types of media content."""
    TEXT = "text"
    IMAGE = "image"
    VIDEO = "video"
    CAROUSEL = "carousel"
    STORY = "story"
    REEL = "reel"
    LIVE = "live"
    ARTICLE = "article"
    THREAD = "thread"


class Platform(Enum):
    """Social media platforms."""
    INSTAGRAM = "instagram"
    TIKTOK = "tiktok"
    TWITTER = "twitter"
    LINKEDIN = "linkedin"
    YOUTUBE = "youtube"
    FACEBOOK = "facebook"
    THREADS = "threads"
    OTHER = "other"


class ContentHook(Enum):
    """Types of content hooks that drive engagement."""
    QUESTION = "question"
    CONTROVERSIAL = "controversial"
    LISTICLE = "listicle"
    HOW_TO = "how_to"
    STORY = "story"
    DATA_INSIGHT = "data_insight"
    PERSONAL_EXPERIENCE = "personal_experience"
    TREND_COMMENTARY = "trend_commentary"
    PREDICTION = "prediction"
    BEHIND_SCENES = "behind_scenes"
    CHALLENGE = "challenge"
    GIVEAWAY = "giveaway"
    COLLABORATION = "collaboration"
    USER_GENERATED = "user_generated"
    OTHER = "other"


class ContentFormat(Enum):
    """Content format patterns."""
    SHORT_FORM = "short_form"  # <60 seconds video, <280 chars text
    LONG_FORM = "long_form"   # >3 min video, >500 chars text
    EDUCATIONAL = "educational"
    ENTERTAINMENT = "entertainment"
    NEWS_UPDATE = "news_update"
    TUTORIAL = "tutorial"
    REVIEW = "review"
    COMPARISON = "comparison"
    INTERVIEW = "interview"
    PODCAST_CLIP = "podcast_clip"
    INFOGRAPHIC = "infographic"


@dataclass
class Comment:
    """Individual comment on a post."""
    comment_id: str
    author_id: str
    author_username: str
    text: str
    timestamp: datetime
    likes: int = 0
    replies_count: int = 0
    sentiment_score: float = 0.0  # -1 to 1
    is_expert: bool = False  # Verified or high-authority commenter
    is_creator_reply: bool = False


@dataclass
class EngagementMetrics:
    """Comprehensive engagement metrics for a post or creator."""
    likes: int = 0
    comments: int = 0
    shares: int = 0
    saves: int = 0
    views: int = 0
    impressions: int = 0
    reach: int = 0
    clicks: int = 0

    # Calculated metrics (populated by analytics)
    engagement_rate: float = 0.0  # (likes + comments + shares + saves) / reach
    engagement_velocity: float = 0.0  # Engagements per hour in first 24h
    viral_coefficient: float = 0.0  # shares / (likes + comments)
    save_rate: float = 0.0  # saves / reach (indicates high-value content)
    comment_quality_score: float = 0.0  # Based on sentiment & depth

    def calculate_total_engagements(self) -> int:
        """Calculate total engagement actions."""
        return self.likes + self.comments + self.shares + self.saves

    def calculate_engagement_rate(self, audience_size: int) -> float:
        """Calculate engagement rate based on audience size."""
        if audience_size == 0:
            return 0.0
        return (self.calculate_total_engagements() / audience_size) * 100


@dataclass
class Post:
    """
    Represents a single social media post with all tracked data.

    Post-level data captures: timestamp, text/media type, hashtags,
    links, topic classification, and engagement metrics.
    """
    post_id: str
    creator_id: str
    platform: Platform

    # Content attributes
    text: str
    media_type: MediaType
    timestamp: datetime
    url: str = ""

    # Classification
    hashtags: List[str] = field(default_factory=list)
    mentions: List[str] = field(default_factory=list)
    links: List[str] = field(default_factory=list)
    topics: List[str] = field(default_factory=list)  # AI-classified topics
    niche_tags: List[str] = field(default_factory=list)

    # Content pattern analysis
    hook_type: Optional[ContentHook] = None
    content_format: Optional[ContentFormat] = None

    # Engagement data
    metrics: EngagementMetrics = field(default_factory=EngagementMetrics)
    comments_list: List[Comment] = field(default_factory=list)

    # Velocity tracking (for trend analysis)
    engagements_1h: int = 0
    engagements_6h: int = 0
    engagements_24h: int = 0
    engagements_48h: int = 0

    # Metadata
    is_sponsored: bool = False
    is_collaboration: bool = False
    collaboration_partners: List[str] = field(default_factory=list)

    def get_engagement_velocity(self) -> float:
        """Calculate engagement velocity (engagements per hour in first 24h)."""
        if self.engagements_24h > 0:
            return self.engagements_24h / 24
        return self.metrics.calculate_total_engagements() / 24

    def get_hashtag_string(self) -> str:
        """Get hashtags as a comma-separated string."""
        return ", ".join(self.hashtags)


@dataclass
class CreatorGrowthMetrics:
    """Tracks creator growth over time."""
    date: datetime
    follower_count: int
    following_count: int
    post_count: int
    avg_engagement_rate: float


@dataclass
class Creator:
    """
    Represents a content creator/influencer profile.

    Creator-level data: follower count, growth rate, avg engagement, niche tags.
    """
    creator_id: str
    username: str
    platform: Platform

    # Profile data
    display_name: str = ""
    bio: str = ""
    profile_url: str = ""

    # Audience metrics
    follower_count: int = 0
    following_count: int = 0

    # Classification
    niche_tags: List[str] = field(default_factory=list)
    primary_niche: str = ""
    secondary_niches: List[str] = field(default_factory=list)

    # Performance metrics
    total_posts: int = 0
    avg_engagement_rate: float = 0.0
    avg_likes: float = 0.0
    avg_comments: float = 0.0
    avg_shares: float = 0.0
    avg_saves: float = 0.0

    # Growth metrics
    follower_growth_rate_7d: float = 0.0  # % growth in 7 days
    follower_growth_rate_30d: float = 0.0  # % growth in 30 days
    growth_history: List[CreatorGrowthMetrics] = field(default_factory=list)

    # Quality indicators
    engagement_quality_score: float = 0.0  # 0-100
    audience_authenticity_score: float = 0.0  # 0-100 (bot detection)
    content_consistency_score: float = 0.0  # 0-100

    # Collaboration data
    collaboration_rate: float = 0.0  # % of posts that are collaborations
    frequent_collaborators: List[str] = field(default_factory=list)

    # Tracking metadata
    first_tracked: Optional[datetime] = None
    last_updated: Optional[datetime] = None
    posts: List[Post] = field(default_factory=list)

    def get_niche_string(self) -> str:
        """Get niches as a formatted string."""
        niches = [self.primary_niche] + self.secondary_niches
        return " | ".join([n for n in niches if n])

    def is_micro_influencer(self) -> bool:
        """Check if creator is a micro-influencer (1K-100K followers)."""
        return 1000 <= self.follower_count <= 100000

    def is_nano_influencer(self) -> bool:
        """Check if creator is a nano-influencer (<1K followers)."""
        return self.follower_count < 1000

    def get_tier(self) -> str:
        """Get influencer tier classification."""
        if self.follower_count >= 1_000_000:
            return "Mega (1M+)"
        elif self.follower_count >= 100_000:
            return "Macro (100K-1M)"
        elif self.follower_count >= 10_000:
            return "Mid-tier (10K-100K)"
        elif self.follower_count >= 1_000:
            return "Micro (1K-10K)"
        else:
            return "Nano (<1K)"


@dataclass
class ContentTaxonomy:
    """
    Content taxonomy for pattern recognition.

    Tracks hooks, formats, and themes to identify "repeatable formulas".
    """
    taxonomy_id: str
    name: str
    description: str

    # Pattern components
    hook_types: List[ContentHook] = field(default_factory=list)
    formats: List[ContentFormat] = field(default_factory=list)
    themes: List[str] = field(default_factory=list)

    # Performance data for this taxonomy
    avg_engagement_rate: float = 0.0
    total_posts_analyzed: int = 0
    success_rate: float = 0.0  # % of posts using this that exceeded avg engagement

    # Examples
    example_posts: List[str] = field(default_factory=list)  # Post IDs

    def get_formula_description(self) -> str:
        """Generate a description of this content formula."""
        hooks = ", ".join([h.value for h in self.hook_types])
        formats = ", ".join([f.value for f in self.formats])
        return f"Hook: {hooks} | Format: {formats} | Themes: {', '.join(self.themes)}"


@dataclass
class TrendingTopic:
    """Represents a trending topic or hashtag."""
    topic: str
    platform: Platform

    # Metrics
    post_count: int = 0
    total_engagement: int = 0
    avg_engagement_rate: float = 0.0
    growth_rate: float = 0.0  # % increase in mentions

    # Time data
    first_seen: Optional[datetime] = None
    peak_date: Optional[datetime] = None

    # Related data
    related_hashtags: List[str] = field(default_factory=list)
    top_creators: List[str] = field(default_factory=list)  # Creator IDs

    # Classification
    category: str = ""
    is_evergreen: bool = False
    estimated_lifespan_days: int = 0


@dataclass
class WhitespaceOpportunity:
    """
    Represents a whitespace opportunity - high demand, low creator saturation.
    """
    opportunity_id: str
    topic: str
    niche: str

    # Demand indicators
    search_volume: int = 0
    engagement_rate: float = 0.0
    audience_interest_score: float = 0.0  # 0-100

    # Supply indicators
    creator_count: int = 0
    post_frequency: float = 0.0  # Posts per day
    competition_score: float = 0.0  # 0-100 (lower = less saturated)

    # Opportunity metrics
    opportunity_score: float = 0.0  # Demand/Supply ratio
    recommended_priority: str = ""  # High, Medium, Low

    # Content suggestions
    suggested_hooks: List[ContentHook] = field(default_factory=list)
    suggested_formats: List[ContentFormat] = field(default_factory=list)
    example_angles: List[str] = field(default_factory=list)


@dataclass
class CollaborationTarget:
    """Represents a potential collaboration partner."""
    creator_id: str
    creator_name: str
    platform: Platform

    # Fit scores
    niche_alignment_score: float = 0.0  # 0-100
    audience_overlap_score: float = 0.0  # 0-100
    engagement_quality_score: float = 0.0  # 0-100
    overall_fit_score: float = 0.0  # 0-100

    # Creator metrics
    follower_count: int = 0
    engagement_rate: float = 0.0
    growth_rate: float = 0.0

    # Collaboration history
    previous_collaborations: int = 0
    collaboration_success_rate: float = 0.0

    # Contact info
    contact_method: str = ""
    notes: str = ""
