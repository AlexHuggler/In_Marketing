"""
Niche Discovery Module

Identifies top creators within specific niches with:
- Fuzzy matching for related niches
- Niche groupings (e.g., "data" includes analytics, science, engineering)
- Quality-based ranking (engagement over followers)
- Cross-niche opportunity detection
"""

from collections import defaultdict
from typing import List, Dict, Any, Optional, Set, Tuple
import re
import statistics

from .models import Post, Creator, Platform


class NicheDiscovery:
    """
    Discover and rank top creators within specific niches.

    Handles fuzzy matching, related niches, and quality-based ranking.
    """

    # Pre-defined niche groups - related terms that should match together
    NICHE_GROUPS = {
        'data': [
            'data', 'data-analytics', 'data analytics', 'analytics',
            'data-science', 'data science', 'datascience',
            'data-engineering', 'data engineering', 'dataengineering',
            'data-visualization', 'data visualization', 'dataviz',
            'big-data', 'big data', 'bigdata',
            'machine-learning', 'machine learning', 'ml',
            'artificial-intelligence', 'artificial intelligence', 'ai',
            'statistics', 'statistical-analysis',
        ],
        'business-intelligence': [
            'business-intelligence', 'business intelligence', 'bi',
            'tableau', 'power-bi', 'power bi', 'powerbi',
            'looker', 'metabase', 'superset',
            'dashboards', 'reporting', 'kpis', 'metrics',
        ],
        'data-professional': [
            'data-professional', 'data professional',
            'data-career', 'data career', 'datacareer',
            'data-training', 'data training',
            'sql', 'python', 'r-programming',
            'excel', 'spreadsheets',
            'data-bootcamp', 'data bootcamp',
        ],
        'tech': [
            'technology', 'tech', 'software', 'programming',
            'coding', 'developer', 'engineering', 'devops',
            'cloud', 'aws', 'azure', 'gcp',
        ],
        'marketing': [
            'marketing', 'digital-marketing', 'digital marketing',
            'content-marketing', 'content marketing',
            'social-media', 'social media', 'socialmedia',
            'seo', 'sem', 'growth', 'growth-hacking',
            'branding', 'advertising', 'ads',
        ],
        'business': [
            'business', 'entrepreneurship', 'startup', 'startups',
            'leadership', 'management', 'strategy',
            'consulting', 'mba', 'finance',
        ],
        'productivity': [
            'productivity', 'efficiency', 'time-management',
            'habits', 'self-improvement', 'personal-development',
            'goal-setting', 'focus', 'deep-work',
        ],
    }

    def __init__(self, creators: Dict[str, Creator], posts: List[Post] = None):
        self.creators = creators
        self.posts = posts or []
        self._build_niche_index()

    def _build_niche_index(self):
        """Build index of creators by niche for fast lookup."""
        self.niche_index = defaultdict(list)

        for creator in self.creators.values():
            for niche in creator.niche_tags:
                normalized = self._normalize_niche(niche)
                self.niche_index[normalized].append(creator)

    def _normalize_niche(self, niche: str) -> str:
        """Normalize niche string for matching."""
        return niche.lower().strip().replace('_', '-').replace('  ', ' ')

    def _get_related_niches(self, niche: str) -> Set[str]:
        """Get all related niches for a given niche."""
        normalized = self._normalize_niche(niche)
        related = {normalized}

        # Check if niche belongs to a group
        for group_name, group_terms in self.NICHE_GROUPS.items():
            normalized_terms = [self._normalize_niche(t) for t in group_terms]

            # If input matches any term in group, include all group terms
            if normalized in normalized_terms or any(normalized in t or t in normalized for t in normalized_terms):
                related.update(normalized_terms)
                related.add(group_name)

        # Also add partial matches (e.g., "data" matches "data-science")
        for indexed_niche in self.niche_index.keys():
            if normalized in indexed_niche or indexed_niche in normalized:
                related.add(indexed_niche)

        return related

    def find_creators_by_niche(
        self,
        niches: List[str],
        include_related: bool = True,
        min_followers: int = 0,
        max_followers: int = float('inf'),
        min_engagement_rate: float = 0.0,
        platforms: List[Platform] = None
    ) -> List[Creator]:
        """
        Find all creators matching the specified niches.

        Args:
            niches: List of niche terms to search for
            include_related: If True, includes related niches (recommended)
            min_followers: Minimum follower count filter
            max_followers: Maximum follower count filter
            min_engagement_rate: Minimum engagement rate filter
            platforms: Filter by specific platforms

        Returns:
            List of matching creators
        """
        matching_creators = set()

        for niche in niches:
            if include_related:
                search_niches = self._get_related_niches(niche)
            else:
                search_niches = {self._normalize_niche(niche)}

            for search_niche in search_niches:
                # Direct match
                if search_niche in self.niche_index:
                    for creator in self.niche_index[search_niche]:
                        matching_creators.add(creator.creator_id)

                # Partial match in creator niches
                for creator in self.creators.values():
                    for creator_niche in creator.niche_tags:
                        normalized_creator_niche = self._normalize_niche(creator_niche)
                        if search_niche in normalized_creator_niche or normalized_creator_niche in search_niche:
                            matching_creators.add(creator.creator_id)

        # Get creator objects and apply filters
        results = []
        for creator_id in matching_creators:
            creator = self.creators[creator_id]

            # Apply filters
            if creator.follower_count < min_followers:
                continue
            if creator.follower_count > max_followers:
                continue
            if creator.avg_engagement_rate < min_engagement_rate:
                continue
            if platforms and creator.platform not in platforms:
                continue

            results.append(creator)

        return results

    def rank_creators_in_niche(
        self,
        niches: List[str],
        ranking_method: str = 'composite',
        include_related: bool = True,
        top_n: int = 50,
        **filters
    ) -> List[Dict[str, Any]]:
        """
        Rank creators within specified niches.

        Args:
            niches: List of niche terms
            ranking_method: One of 'composite', 'engagement', 'growth', 'followers'
            include_related: Include related niches
            top_n: Number of top creators to return
            **filters: Additional filters (min_followers, max_followers, etc.)

        Returns:
            Ranked list of creators with scores
        """
        creators = self.find_creators_by_niche(niches, include_related, **filters)

        if not creators:
            return []

        ranked = []
        for creator in creators:
            # Calculate scores
            engagement_score = min(creator.avg_engagement_rate * 15, 100)  # Normalize to 0-100
            growth_score = min(max(creator.follower_growth_rate_30d, 0) * 3, 100)

            # Calculate niche relevance (how many target niches they match)
            matched_niches = self._count_niche_matches(creator, niches, include_related)
            relevance_score = min(matched_niches * 25, 100)

            # Get creator's posts engagement data
            creator_posts = [p for p in self.posts if p.creator_id == creator.creator_id]
            if creator_posts:
                avg_post_engagement = statistics.mean([
                    p.metrics.calculate_total_engagements() for p in creator_posts
                ])
                consistency = self._calculate_consistency(creator_posts)
            else:
                avg_post_engagement = creator.avg_likes + creator.avg_comments
                consistency = 50

            # Calculate composite score based on method
            if ranking_method == 'engagement':
                score = engagement_score
            elif ranking_method == 'growth':
                score = growth_score
            elif ranking_method == 'followers':
                score = min(creator.follower_count / 10000, 100)  # Normalize
            else:  # composite
                score = (
                    engagement_score * 0.35 +
                    growth_score * 0.20 +
                    relevance_score * 0.25 +
                    consistency * 0.20
                )

            ranked.append({
                'creator_id': creator.creator_id,
                'username': creator.username,
                'display_name': creator.display_name or creator.username,
                'platform': creator.platform.value,
                'tier': creator.get_tier(),
                'follower_count': creator.follower_count,
                'primary_niche': creator.primary_niche,
                'all_niches': ', '.join(creator.niche_tags),
                'matched_niches': matched_niches,
                'avg_engagement_rate': round(creator.avg_engagement_rate, 2),
                'growth_rate_30d': round(creator.follower_growth_rate_30d, 2),
                'engagement_score': round(engagement_score, 1),
                'growth_score': round(growth_score, 1),
                'relevance_score': round(relevance_score, 1),
                'consistency_score': round(consistency, 1),
                'composite_score': round(score, 1),
                'recommendation': self._get_recommendation(score, creator),
            })

        # Sort by score
        ranked.sort(key=lambda x: x['composite_score'], reverse=True)

        return ranked[:top_n]

    def _count_niche_matches(self, creator: Creator, target_niches: List[str], include_related: bool) -> int:
        """Count how many target niches a creator matches."""
        matches = 0
        creator_niches = {self._normalize_niche(n) for n in creator.niche_tags}

        for niche in target_niches:
            if include_related:
                search_niches = self._get_related_niches(niche)
            else:
                search_niches = {self._normalize_niche(niche)}

            if creator_niches.intersection(search_niches):
                matches += 1

        return matches

    def _calculate_consistency(self, posts: List[Post]) -> float:
        """Calculate engagement consistency score."""
        if len(posts) < 2:
            return 50.0

        engagements = [p.metrics.calculate_total_engagements() for p in posts]
        avg = statistics.mean(engagements)

        if avg == 0:
            return 50.0

        std_dev = statistics.stdev(engagements)
        cv = std_dev / avg  # Coefficient of variation

        # Lower CV = more consistent = higher score
        consistency = max(0, 100 - (cv * 50))
        return consistency

    def _get_recommendation(self, score: float, creator: Creator) -> str:
        """Generate recommendation text based on score."""
        if score >= 75:
            return "Highly recommended - top performer in niche"
        elif score >= 60:
            return "Strong candidate - good engagement and relevance"
        elif score >= 45:
            return "Worth considering - solid metrics"
        elif score >= 30:
            return "Monitor - potential but needs validation"
        else:
            return "Lower priority - limited niche fit"

    def get_niche_overview(self, niches: List[str], include_related: bool = True) -> Dict[str, Any]:
        """
        Get an overview of the niche landscape.

        Returns stats about creators, competition, and opportunities.
        """
        creators = self.find_creators_by_niche(niches, include_related)

        if not creators:
            return {
                'total_creators': 0,
                'message': 'No creators found for specified niches'
            }

        # Calculate stats
        follower_counts = [c.follower_count for c in creators]
        engagement_rates = [c.avg_engagement_rate for c in creators if c.avg_engagement_rate > 0]
        growth_rates = [c.follower_growth_rate_30d for c in creators]

        # Tier distribution
        tier_dist = defaultdict(int)
        for c in creators:
            tier_dist[c.get_tier()] += 1

        # Platform distribution
        platform_dist = defaultdict(int)
        for c in creators:
            platform_dist[c.platform.value] += 1

        return {
            'search_niches': niches,
            'related_niches_included': include_related,
            'total_creators': len(creators),
            'follower_stats': {
                'total_reach': sum(follower_counts),
                'avg_followers': int(statistics.mean(follower_counts)),
                'median_followers': int(statistics.median(follower_counts)),
                'max_followers': max(follower_counts),
                'min_followers': min(follower_counts),
            },
            'engagement_stats': {
                'avg_engagement_rate': round(statistics.mean(engagement_rates), 2) if engagement_rates else 0,
                'median_engagement_rate': round(statistics.median(engagement_rates), 2) if engagement_rates else 0,
                'top_engagement_rate': round(max(engagement_rates), 2) if engagement_rates else 0,
            },
            'growth_stats': {
                'avg_growth_30d': round(statistics.mean(growth_rates), 2),
                'creators_growing': sum(1 for g in growth_rates if g > 0),
                'creators_declining': sum(1 for g in growth_rates if g < 0),
            },
            'tier_distribution': dict(tier_dist),
            'platform_distribution': dict(platform_dist),
            'competition_level': self._assess_competition(creators),
        }

    def _assess_competition(self, creators: List[Creator]) -> str:
        """Assess competition level in the niche."""
        if len(creators) < 5:
            return "Low - Few creators, high opportunity"
        elif len(creators) < 20:
            return "Moderate - Growing space with room"
        elif len(creators) < 50:
            return "Medium - Established but not saturated"
        elif len(creators) < 100:
            return "High - Competitive, need differentiation"
        else:
            return "Very High - Saturated market"

    def find_rising_stars(
        self,
        niches: List[str],
        min_growth_rate: float = 5.0,
        max_followers: int = 100000,
        top_n: int = 20
    ) -> List[Dict[str, Any]]:
        """
        Find rising stars - fast-growing creators in the niche.

        These are often better collaboration targets than established accounts.
        """
        creators = self.find_creators_by_niche(
            niches,
            include_related=True,
            max_followers=max_followers
        )

        rising = []
        for creator in creators:
            if creator.follower_growth_rate_30d < min_growth_rate:
                continue

            # Calculate momentum score
            growth_momentum = creator.follower_growth_rate_30d
            engagement_quality = creator.avg_engagement_rate

            # Rising stars have high growth AND high engagement
            star_score = (growth_momentum * 2) + (engagement_quality * 10)

            rising.append({
                'creator_id': creator.creator_id,
                'username': creator.username,
                'display_name': creator.display_name,
                'platform': creator.platform.value,
                'follower_count': creator.follower_count,
                'growth_rate_30d': round(creator.follower_growth_rate_30d, 2),
                'engagement_rate': round(creator.avg_engagement_rate, 2),
                'niches': ', '.join(creator.niche_tags),
                'star_score': round(star_score, 1),
                'potential': self._assess_potential(creator),
            })

        rising.sort(key=lambda x: x['star_score'], reverse=True)
        return rising[:top_n]

    def _assess_potential(self, creator: Creator) -> str:
        """Assess creator's growth potential."""
        if creator.follower_growth_rate_30d > 20 and creator.avg_engagement_rate > 5:
            return "Very High - Viral trajectory with strong engagement"
        elif creator.follower_growth_rate_30d > 10 and creator.avg_engagement_rate > 3:
            return "High - Strong growth with solid engagement"
        elif creator.follower_growth_rate_30d > 5:
            return "Good - Steady growth, worth monitoring"
        else:
            return "Moderate - Growing but slower pace"

    def compare_niches(self, niche_groups: List[List[str]]) -> List[Dict[str, Any]]:
        """
        Compare multiple niche groups to identify best opportunities.

        Args:
            niche_groups: List of niche lists to compare
                          e.g., [['data-analytics'], ['data-science'], ['business-intelligence']]
        """
        comparisons = []

        for niches in niche_groups:
            overview = self.get_niche_overview(niches)

            if overview['total_creators'] == 0:
                continue

            # Calculate opportunity score
            # Higher engagement + lower competition = better opportunity
            avg_engagement = overview['engagement_stats']['avg_engagement_rate']
            creator_count = overview['total_creators']

            # Normalize (fewer creators = higher score)
            competition_factor = max(0, 100 - creator_count) / 100
            opportunity_score = (avg_engagement * 10) * (1 + competition_factor)

            comparisons.append({
                'niches': ', '.join(niches),
                'total_creators': creator_count,
                'total_reach': overview['follower_stats']['total_reach'],
                'avg_engagement': avg_engagement,
                'avg_growth': overview['growth_stats']['avg_growth_30d'],
                'competition': overview['competition_level'],
                'opportunity_score': round(opportunity_score, 1),
            })

        comparisons.sort(key=lambda x: x['opportunity_score'], reverse=True)
        return comparisons


def generate_data_niche_sample_data(
    num_creators: int = 30,
    posts_per_creator: int = 12
) -> Tuple[List[Post], Dict[str, Creator]]:
    """
    Generate sample data specifically for data/analytics niches.

    Includes: data analytics, data science, data engineering,
    business intelligence, data professional training, etc.
    """
    import random
    from datetime import datetime, timedelta
    from .models import EngagementMetrics, MediaType

    DATA_NICHES = [
        ('data-analytics', ['data-analytics', 'analytics', 'sql', 'dashboards']),
        ('data-science', ['data-science', 'machine-learning', 'python', 'statistics']),
        ('data-engineering', ['data-engineering', 'etl', 'data-pipelines', 'big-data']),
        ('business-intelligence', ['business-intelligence', 'tableau', 'power-bi', 'reporting']),
        ('data-training', ['data-training', 'data-career', 'sql-tutorials', 'python-tutorials']),
        ('data-visualization', ['data-visualization', 'dataviz', 'charts', 'storytelling']),
    ]

    PLATFORMS = [Platform.LINKEDIN, Platform.TWITTER, Platform.YOUTUBE, Platform.TIKTOK]

    CONTENT_TEMPLATES = [
        "5 SQL queries every data analyst should know:",
        "How I broke into data science without a CS degree:",
        "The #1 mistake junior data analysts make:",
        "Why your dashboard is failing (and how to fix it):",
        "Python vs R: which should you learn first?",
        "My data engineering interview prep guide:",
        "Tableau tip that will save you hours:",
        "The future of business intelligence in 2024:",
        "How to explain data to non-technical stakeholders:",
        "Data portfolio projects that actually get you hired:",
        "SQL window functions explained simply:",
        "Why I switched from Excel to Python:",
        "Data visualization mistakes to avoid:",
        "Building your first data pipeline:",
        "Power BI vs Tableau: honest comparison:",
    ]

    NAMES = [
        ('Alex', 'Chen'), ('Sarah', 'Kumar'), ('Mike', 'Johnson'), ('Emily', 'Zhang'),
        ('David', 'Williams'), ('Jessica', 'Martinez'), ('Ryan', 'Lee'), ('Amanda', 'Brown'),
        ('Chris', 'Taylor'), ('Laura', 'Anderson'), ('James', 'Wilson'), ('Nicole', 'Thomas'),
        ('Kevin', 'Garcia'), ('Rachel', 'Moore'), ('Daniel', 'Jackson'), ('Stephanie', 'White'),
        ('Andrew', 'Harris'), ('Michelle', 'Clark'), ('Brandon', 'Lewis'), ('Ashley', 'Robinson'),
        ('Tyler', 'Walker'), ('Samantha', 'Hall'), ('Justin', 'Allen'), ('Megan', 'Young'),
        ('Josh', 'King'), ('Brittany', 'Wright'), ('Matt', 'Scott'), ('Kayla', 'Green'),
        ('Adam', 'Baker'), ('Lindsey', 'Adams'),
    ]

    creators = {}
    posts = []

    for i in range(min(num_creators, len(NAMES))):
        first, last = NAMES[i]
        creator_id = f"data_creator_{i:03d}"

        # Assign primary and secondary niches
        primary_niche_data = random.choice(DATA_NICHES)
        primary_niche = primary_niche_data[0]
        niche_tags = primary_niche_data[1].copy()

        # Sometimes add secondary niche
        if random.random() > 0.5:
            secondary = random.choice(DATA_NICHES)
            if secondary[0] != primary_niche:
                niche_tags.extend(secondary[1][:2])

        # Generate follower count with realistic distribution
        tier = random.choices(
            ['nano', 'micro', 'mid', 'macro'],
            weights=[15, 40, 35, 10]
        )[0]

        follower_ranges = {
            'nano': (500, 999),
            'micro': (1000, 9999),
            'mid': (10000, 99999),
            'macro': (100000, 500000),
        }

        follower_count = random.randint(*follower_ranges[tier])
        platform = random.choice(PLATFORMS)

        # Data creators tend to have good engagement
        base_engagement = random.uniform(2.5, 6.0)
        tier_modifier = {'nano': 1.4, 'micro': 1.2, 'mid': 1.0, 'macro': 0.7}
        engagement_rate = base_engagement * tier_modifier[tier]

        # Growth rates
        growth_7d = random.gauss(1.0, 3)
        growth_30d = random.gauss(4.0, 8)

        username_styles = [
            f"{first.lower()}_data",
            f"{first.lower()}{last.lower()}",
            f"data_{first.lower()}",
            f"{first.lower()}.analytics",
            f"{primary_niche.replace('-', '')}_{first.lower()}",
        ]

        creator = Creator(
            creator_id=creator_id,
            username=random.choice(username_styles),
            platform=platform,
            display_name=f"{first} {last}",
            bio=f"{primary_niche.replace('-', ' ').title()} | Helping you become data-driven",
            follower_count=follower_count,
            following_count=random.randint(100, min(2000, follower_count)),
            niche_tags=list(set(niche_tags)),
            primary_niche=primary_niche,
            secondary_niches=niche_tags[1:3],
            avg_engagement_rate=engagement_rate,
            avg_likes=int(follower_count * engagement_rate / 100 * 0.65),
            avg_comments=int(follower_count * engagement_rate / 100 * 0.25),
            total_posts=posts_per_creator,
            follower_growth_rate_7d=growth_7d,
            follower_growth_rate_30d=growth_30d,
            first_tracked=datetime.now() - timedelta(days=30),
            last_updated=datetime.now(),
        )

        creators[creator_id] = creator

        # Generate posts
        for j in range(posts_per_creator):
            post_id = f"post_{creator_id}_{j:03d}"

            timestamp = datetime.now() - timedelta(
                days=random.randint(0, 30),
                hours=random.randint(6, 22),
            )

            text = random.choice(CONTENT_TEMPLATES)
            media_type = random.choice([MediaType.TEXT, MediaType.VIDEO, MediaType.CAROUSEL, MediaType.IMAGE])

            hashtags = [f"#{niche_tags[0].replace('-', '')}", '#data', '#analytics']

            # Engagement with variance
            engagement_mult = random.gauss(1.0, 0.3)
            engagement_mult = max(0.3, engagement_mult)

            base_views = int(follower_count * random.uniform(0.8, 2.5))

            metrics = EngagementMetrics(
                likes=int(base_views * engagement_rate / 100 * 0.65 * engagement_mult),
                comments=int(base_views * engagement_rate / 100 * 0.20 * engagement_mult),
                shares=int(base_views * engagement_rate / 100 * 0.10 * engagement_mult),
                saves=int(base_views * engagement_rate / 100 * 0.05 * engagement_mult),
                views=base_views,
            )

            post = Post(
                post_id=post_id,
                creator_id=creator_id,
                platform=platform,
                text=text,
                media_type=media_type,
                timestamp=timestamp,
                hashtags=hashtags,
                topics=niche_tags[:3],
                metrics=metrics,
            )

            posts.append(post)
            creator.posts.append(post)

    return posts, creators
