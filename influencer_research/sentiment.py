"""
Sentiment Analysis Module

Analyzes comment quality and engagement authenticity:
- Comment sentiment scoring
- Repeated commenter detection
- Expert commenter identification
- Engagement quality scoring
"""

from collections import defaultdict
from typing import List, Dict, Any, Optional, Set
import re
import statistics

from .models import Post, Comment, Creator


class SentimentAnalyzer:
    """
    Analyzes sentiment and quality of engagement.

    Uses rule-based sentiment analysis that can be enhanced with ML models.
    """

    # Positive sentiment indicators
    POSITIVE_WORDS = {
        'love', 'amazing', 'awesome', 'great', 'excellent', 'fantastic',
        'incredible', 'brilliant', 'perfect', 'helpful', 'informative',
        'inspiring', 'valuable', 'thank', 'thanks', 'appreciate', 'best',
        'beautiful', 'wonderful', 'insightful', 'genius', 'fire', 'lit',
        'goated', 'W', 'based', 'real', 'truth', 'exactly', 'agree', 'yes',
    }

    # Negative sentiment indicators
    NEGATIVE_WORDS = {
        'hate', 'terrible', 'awful', 'bad', 'worst', 'horrible', 'stupid',
        'boring', 'useless', 'wrong', 'fake', 'scam', 'spam', 'annoying',
        'misleading', 'garbage', 'trash', 'L', 'cringe', 'cap', 'mid',
        'disagree', 'false', 'lie', 'lying', 'no', 'never',
    }

    # Low-quality engagement indicators (spam/bot patterns)
    SPAM_PATTERNS = [
        r'check out my', r'follow me', r'dm me', r'click link',
        r'free followers', r'make money', r'\$\d+', r'promo code',
        r'bio link', r'link in bio', r'check bio',
        r'^(nice|cool|great|love it|fire|)$',  # Generic low-effort
        r'^[\U0001F600-\U0001F64F]+$',  # Only emojis
    ]

    # Expert indicators
    EXPERT_INDICATORS = [
        'verified', 'author', 'ceo', 'founder', 'phd', 'dr.', 'professor',
        'expert', 'specialist', 'consultant', 'coach', 'trainer',
    ]

    def __init__(self):
        self.spam_patterns = [re.compile(p, re.IGNORECASE) for p in self.SPAM_PATTERNS]

    def analyze_comment_sentiment(self, text: str) -> float:
        """
        Analyze sentiment of a comment.

        Returns score from -1 (very negative) to 1 (very positive).
        """
        if not text:
            return 0.0

        text_lower = text.lower()
        words = set(re.findall(r'\b\w+\b', text_lower))

        positive_count = len(words.intersection(self.POSITIVE_WORDS))
        negative_count = len(words.intersection(self.NEGATIVE_WORDS))

        total = positive_count + negative_count
        if total == 0:
            return 0.0  # Neutral

        sentiment = (positive_count - negative_count) / total
        return max(-1, min(1, sentiment))

    def is_spam_comment(self, text: str) -> bool:
        """Check if a comment appears to be spam or bot-generated."""
        if not text:
            return True

        # Check for spam patterns
        for pattern in self.spam_patterns:
            if pattern.search(text):
                return True

        # Check for very short/generic comments
        if len(text) < 3:
            return True

        return False

    def is_meaningful_comment(self, text: str, min_words: int = 5) -> bool:
        """
        Check if a comment is meaningful/substantive.

        Meaningful comments typically have:
        - Multiple words
        - Specific references
        - Questions or detailed responses
        """
        if not text or self.is_spam_comment(text):
            return False

        word_count = len(text.split())
        if word_count < min_words:
            return False

        # Bonus for questions (engagement drivers)
        has_question = '?' in text

        # Bonus for specific content references
        has_specifics = any(char.isdigit() for char in text) or '@' in text

        return word_count >= min_words or has_question or has_specifics

    def check_expert_commenter(self, username: str, bio: str = "") -> bool:
        """Check if a commenter appears to be an expert/authority."""
        combined = f"{username} {bio}".lower()
        return any(indicator in combined for indicator in self.EXPERT_INDICATORS)

    def analyze_comment(self, comment: Comment) -> Dict[str, Any]:
        """Perform comprehensive analysis on a single comment."""
        return {
            'comment_id': comment.comment_id,
            'sentiment_score': self.analyze_comment_sentiment(comment.text),
            'is_spam': self.is_spam_comment(comment.text),
            'is_meaningful': self.is_meaningful_comment(comment.text),
            'is_expert': comment.is_expert,
            'word_count': len(comment.text.split()),
            'has_question': '?' in comment.text,
        }

    def analyze_post_comments(self, post: Post) -> Dict[str, Any]:
        """Analyze all comments on a post."""
        if not post.comments_list:
            return {
                'total_comments': 0,
                'avg_sentiment': 0.0,
                'spam_percentage': 0.0,
                'meaningful_percentage': 0.0,
                'expert_comments': 0,
                'comment_quality_score': 0.0,
            }

        analyses = [self.analyze_comment(c) for c in post.comments_list]

        spam_count = sum(1 for a in analyses if a['is_spam'])
        meaningful_count = sum(1 for a in analyses if a['is_meaningful'])
        expert_count = sum(1 for a in analyses if a['is_expert'])

        sentiments = [a['sentiment_score'] for a in analyses if not a['is_spam']]
        avg_sentiment = statistics.mean(sentiments) if sentiments else 0.0

        total = len(analyses)
        spam_pct = (spam_count / total) * 100
        meaningful_pct = (meaningful_count / total) * 100

        # Quality score: weighted combination of metrics
        quality_score = (
            (meaningful_pct * 0.4) +
            ((100 - spam_pct) * 0.3) +
            ((avg_sentiment + 1) * 50 * 0.2) +  # Normalize sentiment to 0-100
            (min(expert_count / max(total, 1) * 100, 100) * 0.1)
        )

        return {
            'total_comments': total,
            'avg_sentiment': avg_sentiment,
            'spam_percentage': spam_pct,
            'meaningful_percentage': meaningful_pct,
            'expert_comments': expert_count,
            'comment_quality_score': quality_score,
        }


class EngagementQualityAnalyzer:
    """
    Analyzes overall engagement quality beyond raw numbers.

    Identifies:
    - Repeated commenters (community indicators)
    - Expert/authority engagement
    - Authentic vs bot engagement
    """

    def __init__(self, posts: List[Post]):
        self.posts = posts
        self.sentiment_analyzer = SentimentAnalyzer()

    def identify_repeated_commenters(self, creator_id: str) -> Dict[str, int]:
        """
        Find users who comment repeatedly on a creator's content.

        Repeated commenters indicate strong community/fan base.
        """
        commenter_counts = defaultdict(int)

        for post in self.posts:
            if post.creator_id != creator_id:
                continue

            for comment in post.comments_list:
                commenter_counts[comment.author_username] += 1

        # Filter to those who commented more than once
        return {k: v for k, v in commenter_counts.items() if v > 1}

    def calculate_community_score(self, creator_id: str) -> float:
        """
        Calculate community strength score based on repeated engagement.

        Higher score = stronger, more loyal community.
        """
        repeated = self.identify_repeated_commenters(creator_id)

        creator_posts = [p for p in self.posts if p.creator_id == creator_id]
        if not creator_posts:
            return 0.0

        total_commenters = set()
        for post in creator_posts:
            for comment in post.comments_list:
                total_commenters.add(comment.author_username)

        if not total_commenters:
            return 0.0

        # Percentage of commenters who are repeated
        repeat_percentage = (len(repeated) / len(total_commenters)) * 100

        # Average repeat frequency
        avg_repeats = statistics.mean(repeated.values()) if repeated else 0

        # Community score combines both metrics
        return (repeat_percentage * 0.6) + (min(avg_repeats, 10) * 10 * 0.4)

    def calculate_engagement_authenticity(self, post: Post) -> float:
        """
        Estimate authenticity of engagement (vs bot/spam).

        Returns score from 0 (likely fake) to 100 (likely authentic).
        """
        if not post.comments_list:
            # Without comments, use engagement ratios as proxy
            total_eng = post.metrics.calculate_total_engagements()
            if total_eng == 0:
                return 50.0  # Neutral

            # Suspicious: very high likes but no comments
            like_comment_ratio = post.metrics.likes / max(post.metrics.comments, 1)
            if like_comment_ratio > 100:
                return 30.0  # Suspicious
            elif like_comment_ratio > 50:
                return 50.0
            else:
                return 70.0

        # With comments, analyze quality
        analysis = self.sentiment_analyzer.analyze_post_comments(post)

        # High spam = low authenticity
        authenticity = 100 - analysis['spam_percentage']

        # Meaningful comments boost authenticity
        authenticity += analysis['meaningful_percentage'] * 0.3

        # Expert comments are strong authenticity signal
        authenticity += min(analysis['expert_comments'] * 5, 20)

        return min(max(authenticity, 0), 100)

    def analyze_creator_engagement_quality(self, creator_id: str) -> Dict[str, Any]:
        """Comprehensive engagement quality analysis for a creator."""
        creator_posts = [p for p in self.posts if p.creator_id == creator_id]

        if not creator_posts:
            return {
                'community_score': 0.0,
                'avg_authenticity': 0.0,
                'avg_comment_quality': 0.0,
                'total_posts_analyzed': 0,
            }

        authenticity_scores = [self.calculate_engagement_authenticity(p) for p in creator_posts]
        comment_analyses = [self.sentiment_analyzer.analyze_post_comments(p) for p in creator_posts]

        return {
            'community_score': self.calculate_community_score(creator_id),
            'avg_authenticity': statistics.mean(authenticity_scores),
            'avg_comment_quality': statistics.mean([a['comment_quality_score'] for a in comment_analyses]),
            'avg_sentiment': statistics.mean([a['avg_sentiment'] for a in comment_analyses]),
            'total_posts_analyzed': len(creator_posts),
            'repeated_commenters': len(self.identify_repeated_commenters(creator_id)),
        }

    def rank_creators_by_quality(self, creators: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Rank creators by engagement quality, not quantity.

        Quality metrics:
        - Community strength (repeat engagers)
        - Comment quality (meaningful vs spam)
        - Authenticity (real vs bot engagement)
        """
        rankings = []

        for creator_id, creator in creators.items():
            quality = self.analyze_creator_engagement_quality(creator_id)

            # Overall quality score
            overall_score = (
                quality['community_score'] * 0.35 +
                quality['avg_authenticity'] * 0.35 +
                quality['avg_comment_quality'] * 0.30
            )

            rankings.append({
                'creator_id': creator_id,
                'creator_name': creator.display_name or creator.username,
                'overall_quality_score': overall_score,
                **quality
            })

        return sorted(rankings, key=lambda x: x['overall_quality_score'], reverse=True)
