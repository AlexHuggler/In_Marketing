"""
Analytics Engine for Influencer Research

Provides comprehensive analysis including:
- Engagement rate and velocity calculations
- Trend detection and analysis
- Content taxonomy pattern recognition
- Whitespace opportunity identification
- Creator ranking and scoring
"""

from collections import defaultdict
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import statistics
import re

from .models import (
    Post, Creator, EngagementMetrics, ContentTaxonomy,
    TrendingTopic, WhitespaceOpportunity, CollaborationTarget,
    Platform, MediaType, ContentHook, ContentFormat
)


class EngagementAnalyzer:
    """
    Analyzes engagement metrics for posts and creators.

    Key insight: Track engagement RATE + VELOCITY rather than raw likes.
    Engagement rate shows quality; velocity shows viral potential.
    """

    def __init__(self, posts: List[Post], creators: Dict[str, Creator]):
        self.posts = posts
        self.creators = creators

    def calculate_engagement_rate(self, post: Post, audience_size: int = None) -> float:
        """
        Calculate engagement rate for a post.

        Formula: (likes + comments + shares + saves) / audience_size * 100

        If audience_size not provided, uses views or estimates from creator.
        """
        total_engagements = (
            post.metrics.likes +
            post.metrics.comments +
            post.metrics.shares +
            post.metrics.saves
        )

        if audience_size is None:
            # Use views if available, otherwise use creator's follower count
            if post.metrics.views > 0:
                audience_size = post.metrics.views
            elif post.creator_id in self.creators:
                audience_size = self.creators[post.creator_id].follower_count
            else:
                audience_size = max(post.metrics.likes * 10, 1)  # Estimate

        if audience_size == 0:
            return 0.0

        return (total_engagements / audience_size) * 100

    def calculate_engagement_velocity(self, post: Post) -> float:
        """
        Calculate engagement velocity (engagements per hour).

        High velocity indicates viral potential and algorithm favor.
        """
        if post.engagements_24h > 0:
            return post.engagements_24h / 24
        elif post.engagements_6h > 0:
            return post.engagements_6h / 6
        elif post.engagements_1h > 0:
            return float(post.engagements_1h)
        else:
            # Estimate from total and time since posting
            hours_since_post = max(1, (datetime.now() - post.timestamp).total_seconds() / 3600)
            total_engagements = post.metrics.calculate_total_engagements()
            return total_engagements / hours_since_post

    def calculate_viral_coefficient(self, post: Post) -> float:
        """
        Calculate viral coefficient (share propensity).

        Formula: shares / (likes + comments)
        Higher = more likely to spread beyond immediate audience.
        """
        base_engagement = post.metrics.likes + post.metrics.comments
        if base_engagement == 0:
            return 0.0
        return post.metrics.shares / base_engagement

    def calculate_save_rate(self, post: Post) -> float:
        """
        Calculate save rate (content value indicator).

        High save rate indicates content worth returning to - educational,
        reference material, or highly valuable content.
        """
        if post.metrics.views > 0:
            return (post.metrics.saves / post.metrics.views) * 100
        elif post.metrics.likes > 0:
            return (post.metrics.saves / (post.metrics.likes * 10)) * 100
        return 0.0

    def analyze_post(self, post: Post) -> Dict[str, float]:
        """Perform comprehensive engagement analysis on a single post."""
        return {
            'engagement_rate': self.calculate_engagement_rate(post),
            'engagement_velocity': self.calculate_engagement_velocity(post),
            'viral_coefficient': self.calculate_viral_coefficient(post),
            'save_rate': self.calculate_save_rate(post),
            'total_engagements': post.metrics.calculate_total_engagements(),
        }

    def analyze_all_posts(self) -> List[Dict[str, Any]]:
        """Analyze all posts and return detailed metrics."""
        results = []
        for post in self.posts:
            analysis = self.analyze_post(post)
            results.append({
                'post_id': post.post_id,
                'creator_id': post.creator_id,
                'platform': post.platform.value,
                'timestamp': post.timestamp,
                'text_preview': post.text[:100] + '...' if len(post.text) > 100 else post.text,
                **analysis
            })
        return sorted(results, key=lambda x: x['engagement_rate'], reverse=True)

    def calculate_creator_metrics(self, creator: Creator) -> Dict[str, float]:
        """Calculate aggregate engagement metrics for a creator."""
        creator_posts = [p for p in self.posts if p.creator_id == creator.creator_id]

        if not creator_posts:
            return {
                'avg_engagement_rate': 0.0,
                'avg_velocity': 0.0,
                'consistency_score': 0.0,
                'total_posts': 0,
            }

        engagement_rates = [self.calculate_engagement_rate(p) for p in creator_posts]
        velocities = [self.calculate_engagement_velocity(p) for p in creator_posts]

        avg_rate = statistics.mean(engagement_rates)
        avg_velocity = statistics.mean(velocities)

        # Consistency score: lower standard deviation = more consistent
        if len(engagement_rates) > 1:
            std_dev = statistics.stdev(engagement_rates)
            consistency = max(0, 100 - (std_dev / avg_rate * 100)) if avg_rate > 0 else 0
        else:
            consistency = 50  # Not enough data

        return {
            'avg_engagement_rate': avg_rate,
            'avg_velocity': avg_velocity,
            'consistency_score': consistency,
            'total_posts': len(creator_posts),
            'best_engagement_rate': max(engagement_rates),
            'worst_engagement_rate': min(engagement_rates),
        }

    def rank_creators_by_engagement(self) -> List[Tuple[Creator, Dict[str, float]]]:
        """
        Rank creators by engagement quality, not just size.

        Key insight: Niche alignment matters more than scale.
        A micro-influencer with 5% engagement beats a mega-influencer with 0.5%.
        """
        rankings = []
        for creator in self.creators.values():
            metrics = self.calculate_creator_metrics(creator)
            rankings.append((creator, metrics))

        # Sort by engagement rate (quality over quantity)
        return sorted(rankings, key=lambda x: x[1]['avg_engagement_rate'], reverse=True)

    def identify_fastest_growing(self, min_posts: int = 3) -> List[Tuple[Creator, float]]:
        """
        Identify fastest-growing creators by engagement trajectory.

        Looks at engagement rate trend over time, not just follower growth.
        """
        growth_scores = []

        for creator in self.creators.values():
            creator_posts = sorted(
                [p for p in self.posts if p.creator_id == creator.creator_id],
                key=lambda x: x.timestamp
            )

            if len(creator_posts) < min_posts:
                continue

            # Calculate engagement rates for recent vs older posts
            midpoint = len(creator_posts) // 2
            older_posts = creator_posts[:midpoint]
            newer_posts = creator_posts[midpoint:]

            old_avg = statistics.mean([self.calculate_engagement_rate(p) for p in older_posts])
            new_avg = statistics.mean([self.calculate_engagement_rate(p) for p in newer_posts])

            if old_avg > 0:
                growth_rate = ((new_avg - old_avg) / old_avg) * 100
            else:
                growth_rate = new_avg * 100 if new_avg > 0 else 0

            growth_scores.append((creator, growth_rate))

        return sorted(growth_scores, key=lambda x: x[1], reverse=True)

    def get_top_performing_posts(self, n: int = 10, by_metric: str = 'engagement_rate') -> List[Post]:
        """Get top performing posts by specified metric."""
        analyzed = self.analyze_all_posts()
        sorted_posts = sorted(analyzed, key=lambda x: x.get(by_metric, 0), reverse=True)

        top_ids = [p['post_id'] for p in sorted_posts[:n]]
        return [p for p in self.posts if p.post_id in top_ids]


class TrendAnalyzer:
    """
    Analyzes trends in topics, hashtags, and content patterns.

    Identifies trending topics and winning content formulas.
    """

    def __init__(self, posts: List[Post]):
        self.posts = posts
        self.engagement_analyzer = None

    def set_engagement_analyzer(self, analyzer: EngagementAnalyzer):
        """Set engagement analyzer for weighted trend analysis."""
        self.engagement_analyzer = analyzer

    def analyze_hashtag_performance(self) -> List[Dict[str, Any]]:
        """
        Analyze performance of hashtags across all posts.

        Returns hashtags ranked by avg engagement of posts using them.
        """
        hashtag_stats = defaultdict(lambda: {
            'posts': [],
            'total_engagement': 0,
            'total_likes': 0,
            'total_comments': 0,
        })

        for post in self.posts:
            for hashtag in post.hashtags:
                tag = hashtag.lower().strip('#')
                hashtag_stats[tag]['posts'].append(post)
                hashtag_stats[tag]['total_engagement'] += post.metrics.calculate_total_engagements()
                hashtag_stats[tag]['total_likes'] += post.metrics.likes
                hashtag_stats[tag]['total_comments'] += post.metrics.comments

        results = []
        for hashtag, stats in hashtag_stats.items():
            post_count = len(stats['posts'])
            if post_count == 0:
                continue

            avg_engagement = stats['total_engagement'] / post_count

            # Calculate engagement rates if analyzer available
            if self.engagement_analyzer:
                rates = [self.engagement_analyzer.calculate_engagement_rate(p) for p in stats['posts']]
                avg_rate = statistics.mean(rates)
            else:
                avg_rate = 0

            results.append({
                'hashtag': f"#{hashtag}",
                'post_count': post_count,
                'total_engagement': stats['total_engagement'],
                'avg_engagement': avg_engagement,
                'avg_engagement_rate': avg_rate,
                'avg_likes': stats['total_likes'] / post_count,
                'avg_comments': stats['total_comments'] / post_count,
            })

        return sorted(results, key=lambda x: x['avg_engagement_rate'], reverse=True)

    def analyze_topic_performance(self) -> List[Dict[str, Any]]:
        """Analyze performance by topic classification."""
        topic_stats = defaultdict(lambda: {
            'posts': [],
            'total_engagement': 0,
        })

        for post in self.posts:
            for topic in post.topics:
                topic_stats[topic.lower()]['posts'].append(post)
                topic_stats[topic.lower()]['total_engagement'] += post.metrics.calculate_total_engagements()

        results = []
        for topic, stats in topic_stats.items():
            post_count = len(stats['posts'])
            if post_count == 0:
                continue

            if self.engagement_analyzer:
                rates = [self.engagement_analyzer.calculate_engagement_rate(p) for p in stats['posts']]
                avg_rate = statistics.mean(rates)
            else:
                avg_rate = 0

            results.append({
                'topic': topic,
                'post_count': post_count,
                'total_engagement': stats['total_engagement'],
                'avg_engagement': stats['total_engagement'] / post_count,
                'avg_engagement_rate': avg_rate,
            })

        return sorted(results, key=lambda x: x['avg_engagement_rate'], reverse=True)

    def identify_trending_topics(self, days_window: int = 7) -> List[TrendingTopic]:
        """
        Identify topics gaining momentum recently.

        Compares recent performance to historical baseline.
        """
        cutoff = datetime.now() - timedelta(days=days_window)
        recent_posts = [p for p in self.posts if p.timestamp >= cutoff]
        older_posts = [p for p in self.posts if p.timestamp < cutoff]

        # Count topics in each period
        recent_topics = defaultdict(int)
        older_topics = defaultdict(int)

        for post in recent_posts:
            for topic in post.topics:
                recent_topics[topic.lower()] += 1
            for tag in post.hashtags:
                recent_topics[tag.lower().strip('#')] += 1

        for post in older_posts:
            for topic in post.topics:
                older_topics[topic.lower()] += 1
            for tag in post.hashtags:
                older_topics[tag.lower().strip('#')] += 1

        # Calculate growth rates
        trending = []
        for topic, recent_count in recent_topics.items():
            old_count = older_topics.get(topic, 0)
            if old_count > 0:
                growth_rate = ((recent_count - old_count) / old_count) * 100
            else:
                growth_rate = 100.0  # New topic

            # Get engagement data
            topic_posts = [
                p for p in recent_posts
                if topic in [t.lower() for t in p.topics] or topic in [h.lower().strip('#') for h in p.hashtags]
            ]
            total_engagement = sum(p.metrics.calculate_total_engagements() for p in topic_posts)
            avg_engagement = total_engagement / len(topic_posts) if topic_posts else 0

            trending.append(TrendingTopic(
                topic=topic,
                platform=Platform.OTHER,  # Multi-platform
                post_count=recent_count,
                total_engagement=total_engagement,
                avg_engagement_rate=avg_engagement,
                growth_rate=growth_rate,
                first_seen=min((p.timestamp for p in topic_posts), default=None),
            ))

        return sorted(trending, key=lambda x: x.growth_rate, reverse=True)

    def analyze_timing_performance(self) -> Dict[str, Any]:
        """Analyze best posting times by day and hour."""
        day_stats = defaultdict(lambda: {'posts': [], 'total_engagement': 0})
        hour_stats = defaultdict(lambda: {'posts': [], 'total_engagement': 0})

        for post in self.posts:
            day = post.timestamp.strftime('%A')
            hour = post.timestamp.hour

            day_stats[day]['posts'].append(post)
            day_stats[day]['total_engagement'] += post.metrics.calculate_total_engagements()

            hour_stats[hour]['posts'].append(post)
            hour_stats[hour]['total_engagement'] += post.metrics.calculate_total_engagements()

        best_days = []
        for day, stats in day_stats.items():
            avg_eng = stats['total_engagement'] / len(stats['posts']) if stats['posts'] else 0
            best_days.append({'day': day, 'avg_engagement': avg_eng, 'post_count': len(stats['posts'])})

        best_hours = []
        for hour, stats in hour_stats.items():
            avg_eng = stats['total_engagement'] / len(stats['posts']) if stats['posts'] else 0
            best_hours.append({'hour': f"{hour:02d}:00", 'avg_engagement': avg_eng, 'post_count': len(stats['posts'])})

        return {
            'best_days': sorted(best_days, key=lambda x: x['avg_engagement'], reverse=True),
            'best_hours': sorted(best_hours, key=lambda x: x['avg_engagement'], reverse=True),
        }


class ContentPatternAnalyzer:
    """
    Analyzes content patterns to identify "repeatable formulas".

    Builds a content taxonomy of hooks, formats, and themes that drive engagement.
    """

    # Patterns for detecting content hooks
    HOOK_PATTERNS = {
        ContentHook.QUESTION: [r'\?$', r'^(what|how|why|when|where|who|which|do you|can you|have you)', r'wondering'],
        ContentHook.LISTICLE: [r'\d+\s+(ways|tips|things|reasons|steps|secrets|hacks|mistakes)', r'here are', r'top \d+'],
        ContentHook.HOW_TO: [r'how to', r'guide to', r'tutorial', r'step.by.step', r'learn how'],
        ContentHook.CONTROVERSIAL: [r'hot take', r'unpopular opinion', r'controversial', r'people don\'t realize', r'truth about'],
        ContentHook.STORY: [r'story time', r'let me tell you', r'i remember when', r'true story', r'my experience'],
        ContentHook.DATA_INSIGHT: [r'\d+%', r'study shows', r'research', r'data reveals', r'statistics'],
        ContentHook.PERSONAL_EXPERIENCE: [r'^i ', r'my journey', r'what i learned', r'personal', r'changed my life'],
        ContentHook.PREDICTION: [r'prediction', r'will happen', r'future of', r'in 202\d', r'next year'],
        ContentHook.BEHIND_SCENES: [r'behind the scenes', r'bts', r'how we', r'day in the life', r'process'],
    }

    def __init__(self, posts: List[Post]):
        self.posts = posts

    def detect_content_hook(self, text: str) -> Optional[ContentHook]:
        """Detect the primary content hook used in text."""
        text_lower = text.lower()

        for hook, patterns in self.HOOK_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, text_lower):
                    return hook

        return ContentHook.OTHER

    def detect_content_format(self, post: Post) -> ContentFormat:
        """Detect content format based on media type and text length."""
        text_length = len(post.text)

        if post.media_type in [MediaType.REEL, MediaType.STORY]:
            return ContentFormat.SHORT_FORM
        elif post.media_type == MediaType.ARTICLE:
            return ContentFormat.LONG_FORM
        elif post.media_type == MediaType.VIDEO:
            return ContentFormat.LONG_FORM  # Assume long-form video

        # Text-based detection
        if text_length < 280:
            return ContentFormat.SHORT_FORM
        elif text_length > 500:
            return ContentFormat.LONG_FORM

        # Content-based detection
        text_lower = post.text.lower()
        if 'tutorial' in text_lower or 'how to' in text_lower or 'learn' in text_lower:
            return ContentFormat.EDUCATIONAL
        if 'review' in text_lower or 'rating' in text_lower:
            return ContentFormat.REVIEW
        if 'vs' in text_lower or 'versus' in text_lower or 'comparison' in text_lower:
            return ContentFormat.COMPARISON

        return ContentFormat.SHORT_FORM

    def classify_posts(self) -> List[Dict[str, Any]]:
        """Classify all posts by hook and format."""
        classified = []
        for post in self.posts:
            hook = self.detect_content_hook(post.text)
            format_type = self.detect_content_format(post)

            classified.append({
                'post_id': post.post_id,
                'hook': hook.value,
                'format': format_type.value,
                'text_preview': post.text[:100],
                'engagement': post.metrics.calculate_total_engagements(),
            })

        return classified

    def analyze_pattern_performance(self) -> Dict[str, Any]:
        """Analyze which content patterns perform best."""
        hook_stats = defaultdict(lambda: {'posts': [], 'total_engagement': 0})
        format_stats = defaultdict(lambda: {'posts': [], 'total_engagement': 0})

        for post in self.posts:
            hook = self.detect_content_hook(post.text)
            format_type = self.detect_content_format(post)
            engagement = post.metrics.calculate_total_engagements()

            hook_stats[hook.value]['posts'].append(post)
            hook_stats[hook.value]['total_engagement'] += engagement

            format_stats[format_type.value]['posts'].append(post)
            format_stats[format_type.value]['total_engagement'] += engagement

        hook_results = []
        for hook, stats in hook_stats.items():
            count = len(stats['posts'])
            if count > 0:
                hook_results.append({
                    'hook': hook,
                    'post_count': count,
                    'avg_engagement': stats['total_engagement'] / count,
                    'total_engagement': stats['total_engagement'],
                })

        format_results = []
        for fmt, stats in format_stats.items():
            count = len(stats['posts'])
            if count > 0:
                format_results.append({
                    'format': fmt,
                    'post_count': count,
                    'avg_engagement': stats['total_engagement'] / count,
                    'total_engagement': stats['total_engagement'],
                })

        return {
            'hooks': sorted(hook_results, key=lambda x: x['avg_engagement'], reverse=True),
            'formats': sorted(format_results, key=lambda x: x['avg_engagement'], reverse=True),
        }

    def identify_winning_formulas(self, min_posts: int = 3) -> List[ContentTaxonomy]:
        """
        Identify winning content formulas (hook + format + theme combinations).

        A "formula" is a repeatable pattern that consistently drives engagement.
        """
        formula_stats = defaultdict(lambda: {'posts': [], 'total_engagement': 0})

        for post in self.posts:
            hook = self.detect_content_hook(post.text)
            format_type = self.detect_content_format(post)
            themes = tuple(sorted(post.topics[:2])) if post.topics else ('general',)

            formula_key = (hook.value, format_type.value, themes)
            formula_stats[formula_key]['posts'].append(post)
            formula_stats[formula_key]['total_engagement'] += post.metrics.calculate_total_engagements()

        formulas = []
        for (hook, fmt, themes), stats in formula_stats.items():
            if len(stats['posts']) < min_posts:
                continue

            avg_engagement = stats['total_engagement'] / len(stats['posts'])

            # Calculate success rate (% above average)
            overall_avg = sum(p.metrics.calculate_total_engagements() for p in self.posts) / len(self.posts)
            success_count = sum(1 for p in stats['posts'] if p.metrics.calculate_total_engagements() > overall_avg)
            success_rate = (success_count / len(stats['posts'])) * 100

            taxonomy = ContentTaxonomy(
                taxonomy_id=f"{hook}_{fmt}_{'-'.join(themes)}",
                name=f"{hook.title()} {fmt.title()}",
                description=f"Posts using {hook} hook with {fmt} format about {', '.join(themes)}",
                hook_types=[ContentHook(hook)],
                formats=[ContentFormat(fmt)],
                themes=list(themes),
                avg_engagement_rate=avg_engagement,
                total_posts_analyzed=len(stats['posts']),
                success_rate=success_rate,
                example_posts=[p.post_id for p in stats['posts'][:3]],
            )
            formulas.append(taxonomy)

        return sorted(formulas, key=lambda x: x.avg_engagement_rate, reverse=True)


class WhitespaceAnalyzer:
    """
    Identifies whitespace opportunities: high-demand topics with low creator saturation.

    Key insight: Find topics where audience interest exceeds content supply.
    """

    def __init__(self, posts: List[Post], creators: Dict[str, Creator]):
        self.posts = posts
        self.creators = creators

    def analyze_topic_saturation(self) -> List[Dict[str, Any]]:
        """
        Analyze creator saturation for each topic.

        Lower saturation + high engagement = opportunity.
        """
        topic_data = defaultdict(lambda: {
            'creators': set(),
            'posts': [],
            'total_engagement': 0,
        })

        for post in self.posts:
            for topic in post.topics:
                topic_lower = topic.lower()
                topic_data[topic_lower]['creators'].add(post.creator_id)
                topic_data[topic_lower]['posts'].append(post)
                topic_data[topic_lower]['total_engagement'] += post.metrics.calculate_total_engagements()

        results = []
        for topic, data in topic_data.items():
            post_count = len(data['posts'])
            creator_count = len(data['creators'])

            if post_count == 0:
                continue

            avg_engagement = data['total_engagement'] / post_count
            posts_per_creator = post_count / creator_count if creator_count > 0 else 0

            # Saturation score: more creators = higher saturation
            # Normalize to 0-100 scale
            max_creators = len(self.creators) or 1
            saturation_score = (creator_count / max_creators) * 100

            # Opportunity score: high engagement + low saturation
            opportunity_score = avg_engagement * (100 - saturation_score) / 100

            results.append({
                'topic': topic,
                'creator_count': creator_count,
                'post_count': post_count,
                'avg_engagement': avg_engagement,
                'saturation_score': saturation_score,
                'opportunity_score': opportunity_score,
            })

        return sorted(results, key=lambda x: x['opportunity_score'], reverse=True)

    def identify_whitespace_opportunities(self, min_engagement: float = 100) -> List[WhitespaceOpportunity]:
        """
        Identify specific whitespace opportunities.

        Criteria:
        - High engagement rate (audience demand)
        - Low creator count (supply gap)
        - Growing trend (momentum)
        """
        saturation_data = self.analyze_topic_saturation()

        opportunities = []
        for data in saturation_data:
            if data['avg_engagement'] < min_engagement:
                continue

            # Determine priority
            if data['opportunity_score'] > 500:
                priority = "High"
            elif data['opportunity_score'] > 200:
                priority = "Medium"
            else:
                priority = "Low"

            # Suggest content approaches
            suggested_hooks = [ContentHook.HOW_TO, ContentHook.LISTICLE, ContentHook.PERSONAL_EXPERIENCE]

            opportunity = WhitespaceOpportunity(
                opportunity_id=f"ws_{data['topic'].replace(' ', '_')}",
                topic=data['topic'],
                niche=data['topic'],
                engagement_rate=data['avg_engagement'],
                creator_count=data['creator_count'],
                competition_score=data['saturation_score'],
                opportunity_score=data['opportunity_score'],
                recommended_priority=priority,
                suggested_hooks=suggested_hooks,
                suggested_formats=[ContentFormat.EDUCATIONAL, ContentFormat.SHORT_FORM],
                example_angles=[
                    f"Beginner's guide to {data['topic']}",
                    f"Common mistakes in {data['topic']}",
                    f"My journey learning {data['topic']}",
                ],
            )
            opportunities.append(opportunity)

        return opportunities

    def find_underserved_niches(self) -> List[Dict[str, Any]]:
        """
        Find niches that are underserved relative to engagement.

        Compares creator count to engagement potential.
        """
        niche_data = defaultdict(lambda: {
            'creators': [],
            'total_followers': 0,
            'avg_engagement_rate': [],
        })

        for creator in self.creators.values():
            for niche in creator.niche_tags:
                niche_lower = niche.lower()
                niche_data[niche_lower]['creators'].append(creator)
                niche_data[niche_lower]['total_followers'] += creator.follower_count
                if creator.avg_engagement_rate > 0:
                    niche_data[niche_lower]['avg_engagement_rate'].append(creator.avg_engagement_rate)

        results = []
        for niche, data in niche_data.items():
            creator_count = len(data['creators'])
            if creator_count == 0:
                continue

            avg_eng_rate = statistics.mean(data['avg_engagement_rate']) if data['avg_engagement_rate'] else 0

            # Opportunity: high engagement rate but few creators
            results.append({
                'niche': niche,
                'creator_count': creator_count,
                'total_audience': data['total_followers'],
                'avg_engagement_rate': avg_eng_rate,
                'audience_per_creator': data['total_followers'] / creator_count,
            })

        return sorted(results, key=lambda x: x['avg_engagement_rate'], reverse=True)


class CollaborationAnalyzer:
    """
    Identifies potential collaboration targets based on niche alignment
    and engagement quality rather than just follower count.
    """

    def __init__(self, creators: Dict[str, Creator], target_niches: List[str]):
        self.creators = creators
        self.target_niches = [n.lower() for n in target_niches]

    def calculate_niche_alignment(self, creator: Creator) -> float:
        """Calculate how well a creator aligns with target niches."""
        creator_niches = [n.lower() for n in creator.niche_tags]

        if not creator_niches or not self.target_niches:
            return 0.0

        # Count matching niches
        matches = sum(1 for n in creator_niches if n in self.target_niches)
        alignment = (matches / len(self.target_niches)) * 100

        return min(alignment, 100.0)

    def score_collaboration_potential(self, creator: Creator) -> CollaborationTarget:
        """Score a creator as a potential collaboration partner."""
        niche_score = self.calculate_niche_alignment(creator)

        # Engagement quality score (normalize to 0-100)
        eng_score = min(creator.avg_engagement_rate * 20, 100)  # 5% rate = 100 score

        # Growth score (fast-growing creators are valuable)
        growth_score = min(creator.follower_growth_rate_30d * 5, 100)  # 20% monthly growth = 100

        # Overall fit score (weighted average)
        overall_score = (niche_score * 0.4) + (eng_score * 0.35) + (growth_score * 0.25)

        return CollaborationTarget(
            creator_id=creator.creator_id,
            creator_name=creator.display_name or creator.username,
            platform=creator.platform,
            niche_alignment_score=niche_score,
            engagement_quality_score=eng_score,
            overall_fit_score=overall_score,
            follower_count=creator.follower_count,
            engagement_rate=creator.avg_engagement_rate,
            growth_rate=creator.follower_growth_rate_30d,
        )

    def find_collaboration_targets(
        self,
        min_followers: int = 1000,
        max_followers: int = 1000000,
        min_alignment: float = 30
    ) -> List[CollaborationTarget]:
        """
        Find best collaboration targets.

        Key insight: Niche alignment matters more than scale.
        Focus on creators whose audience matches your target market.
        """
        targets = []

        for creator in self.creators.values():
            # Filter by follower count
            if not (min_followers <= creator.follower_count <= max_followers):
                continue

            target = self.score_collaboration_potential(creator)

            # Filter by minimum alignment
            if target.niche_alignment_score < min_alignment:
                continue

            targets.append(target)

        return sorted(targets, key=lambda x: x.overall_fit_score, reverse=True)
