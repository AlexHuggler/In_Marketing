"""
High-Value Moment Notification System

Evaluates analytics results for significant moments worth notifying users about.
Designed to work alongside the existing ReportGenerator pipeline.

Each notification must answer: "Why do I care about this right now?"
"""

import json
import statistics
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from pathlib import Path
from dataclasses import dataclass, field

from .models import Post, Creator, WhitespaceOpportunity
from .analytics import EngagementAnalyzer


# Cooldown hours per event category
COOLDOWN_HOURS = {
    "engagement_anomaly": 4,
    "optimal_timing": 168,   # 7 days
    "creator_milestone": 24,
    "feature_discovery": 72,
}


@dataclass
class NotificationCandidate:
    """Pre-scoring notification candidate."""
    event_type: str
    title: str
    body: str
    deduplication_key: str
    related_creator_id: Optional[str] = None
    related_post_id: Optional[str] = None
    magnitude_score: float = 0.0
    novelty_score: float = 0.0
    relevance_score: float = 0.0
    actionability_score: float = 0.0


@dataclass
class NotificationItem:
    """Scored, qualified notification ready for delivery."""
    notification_id: str
    event_type: str
    title: str
    body: str
    value_score: float
    created_at: datetime
    is_read: bool = False
    related_creator_id: Optional[str] = None
    related_post_id: Optional[str] = None
    deduplication_key: str = ""
    magnitude_score: float = 0.0
    novelty_score: float = 0.0
    relevance_score: float = 0.0
    actionability_score: float = 0.0


@dataclass
class NotificationPreferences:
    """User notification preferences."""
    is_enabled: bool = True
    anomaly_alerts_enabled: bool = True
    timing_alerts_enabled: bool = True
    milestone_alerts_enabled: bool = True
    feature_discovery_enabled: bool = True
    max_notifications_per_day: int = 3
    minimum_value_threshold: float = 0.6


@dataclass
class NotificationHistory:
    """Persisted notification state."""
    items: List[NotificationItem] = field(default_factory=list)
    last_updated: Optional[datetime] = None
    previous_creator_scores: Dict[str, float] = field(default_factory=dict)
    previous_growth_rates: Dict[str, float] = field(default_factory=dict)
    previous_avg_engagement_rate: float = 0.0


class NotificationEvaluator:
    """
    Evaluates analytics results for high-value notification moments.

    Usage:
        evaluator = NotificationEvaluator()
        notifications = evaluator.evaluate(
            posts=posts,
            creators=creators,
            rankings=rankings,
            whitespace_opportunities=whitespace,
            timing_data=timing,
            executive_summary=summary,
            watched_creator_ids={"creator_001", "creator_005"},
        )
    """

    def __init__(
        self,
        preferences: Optional[NotificationPreferences] = None,
        history_path: Optional[str] = None,
    ):
        self.preferences = preferences or NotificationPreferences()
        self.history_path = history_path or "./notification_history.json"
        self.history = self._load_history()

    def evaluate(
        self,
        posts: List[Post],
        creators: Dict[str, Creator],
        rankings: List[Dict[str, Any]],
        whitespace_opportunities: List[WhitespaceOpportunity],
        timing_data: Dict[str, Any],
        executive_summary: Dict[str, Any],
        watched_creator_ids: Optional[set] = None,
    ) -> List[NotificationItem]:
        """
        Main entry point. Evaluate all report results and return
        qualified high-value notifications.
        """
        if not self.preferences.is_enabled:
            return []

        watched = watched_creator_ids or set()
        candidates: List[NotificationCandidate] = []

        if self.preferences.anomaly_alerts_enabled:
            candidates.extend(self._detect_anomalies(posts, creators))

        if self.preferences.timing_alerts_enabled:
            candidates.extend(self._detect_timing_opportunity(timing_data))

        if self.preferences.milestone_alerts_enabled:
            candidates.extend(self._detect_milestones(rankings, watched))

        if self.preferences.feature_discovery_enabled:
            candidates.extend(
                self._detect_feature_opportunities(whitespace_opportunities)
            )

        # Score, filter, rate-limit
        scored = [self._score(c, watched) for c in candidates]
        qualified = [
            n for n in scored
            if n.value_score >= self.preferences.minimum_value_threshold
            and not self._is_duplicate(n)
            and not self._is_in_cooldown(n.event_type)
        ]
        qualified.sort(key=lambda n: n.value_score, reverse=True)

        budget = self._daily_budget_remaining()
        to_deliver = qualified[:budget]

        # Persist
        self.history.items.extend(to_deliver)
        self._update_snapshots(rankings, executive_summary)
        self._save_history()

        return to_deliver

    # -- Detection Methods --

    def _detect_anomalies(
        self,
        posts: List[Post],
        creators: Dict[str, Creator],
    ) -> List[NotificationCandidate]:
        analyzer = EngagementAnalyzer(posts, creators)
        candidates = []

        for creator in creators.values():
            metrics = analyzer.calculate_creator_metrics(creator)
            if metrics['total_posts'] < 3:
                continue

            creator_posts = [p for p in posts if p.creator_id == creator.creator_id]
            rates = [analyzer.calculate_engagement_rate(p) for p in creator_posts]

            if len(rates) < 2:
                continue

            avg = metrics['avg_engagement_rate']
            std = statistics.stdev(rates) if len(rates) > 1 else 0
            if std == 0:
                continue

            for post, rate in zip(creator_posts, rates):
                z_score = (rate - avg) / std
                if z_score <= 2.0:
                    continue

                multiplier = rate / max(avg, 0.01)
                display_name = creator.display_name or creator.username

                candidates.append(NotificationCandidate(
                    event_type="engagement_anomaly",
                    title="Engagement Spike Detected",
                    body=(
                        f"{display_name}'s post is outperforming their average by "
                        f"{multiplier:.1f}x ({rate:.1f}% vs. usual {avg:.1f}%). "
                        f"Worth studying what worked."
                    ),
                    deduplication_key=f"anomaly_{creator.creator_id}_{post.post_id}",
                    related_creator_id=creator.creator_id,
                    related_post_id=post.post_id,
                    magnitude_score=min(1.0, z_score / 4.0),
                    actionability_score=0.8,
                ))

        # Return only top 2 most extreme
        candidates.sort(key=lambda c: c.magnitude_score, reverse=True)
        return candidates[:2]

    def _detect_timing_opportunity(
        self, timing_data: Dict[str, Any]
    ) -> List[NotificationCandidate]:
        now = datetime.now()
        current_day = now.strftime('%A')
        current_hour = now.hour

        best_days = timing_data.get('best_days', [])
        best_hours = timing_data.get('best_hours', [])

        top_days = [d.get('day', d.get('label', '')) for d in best_days[:2]]
        if current_day not in top_days:
            return []

        for hour_item in best_hours[:3]:
            hour_str = hour_item.get('hour', hour_item.get('label', ''))
            hour_str = hour_str.replace(':00', '')
            try:
                best_hour = int(hour_str)
            except ValueError:
                continue

            avg_eng = hour_item.get('avg_engagement', hour_item.get('avgEngagement', 0))

            if abs(current_hour - best_hour) <= 2:
                return [NotificationCandidate(
                    event_type="optimal_timing",
                    title="Prime Posting Window",
                    body=(
                        f"Your data shows {current_day}s at {hour_str}:00 drive "
                        f"{avg_eng:.0f} avg engagement. "
                        f"The next 2 hours are your sweet spot."
                    ),
                    deduplication_key=f"timing_{current_day}_{hour_str}",
                    magnitude_score=0.7,
                    actionability_score=1.0,
                )]

        return []

    def _detect_milestones(
        self,
        rankings: List[Dict[str, Any]],
        watched_ids: set,
    ) -> List[NotificationCandidate]:
        candidates = []

        for r in rankings:
            creator_id = r.get('creator_id', '')
            if creator_id not in watched_ids:
                continue

            prev_score = self.history.previous_creator_scores.get(creator_id, 0)
            prev_growth = self.history.previous_growth_rates.get(creator_id, 0)
            current_score = r.get('composite_score', 0)
            current_growth = r.get('growth_rate_30d', 0)
            display_name = r.get('display_name') or r.get('username', 'Unknown')

            # Score crossed 75
            if current_score >= 75 and prev_score < 75 and prev_score > 0:
                candidates.append(NotificationCandidate(
                    event_type="creator_milestone",
                    title="Creator Milestone",
                    body=(
                        f"{display_name} just reached 'Highly Recommended' status "
                        f"(score: {current_score:.0f}). Their engagement and growth "
                        f"are accelerating."
                    ),
                    deduplication_key=f"milestone_score_{creator_id}",
                    related_creator_id=creator_id,
                    magnitude_score=min(1.0, current_score / 100.0),
                    actionability_score=0.6,
                ))

            # Growth crossed 10%
            if current_growth >= 10.0 and prev_growth < 10.0 and prev_growth > 0:
                candidates.append(NotificationCandidate(
                    event_type="creator_milestone",
                    title="Rising Star Alert",
                    body=(
                        f"{display_name} just crossed 10% monthly growth "
                        f"(now at {current_growth:.1f}%). "
                        f"Might be time to reach out for a collaboration."
                    ),
                    deduplication_key=f"milestone_growth_{creator_id}",
                    related_creator_id=creator_id,
                    magnitude_score=min(1.0, current_growth / 20.0),
                    actionability_score=0.6,
                ))

        return candidates

    def _detect_feature_opportunities(
        self, whitespace: List[WhitespaceOpportunity]
    ) -> List[NotificationCandidate]:
        high_priority = [
            w for w in whitespace
            if w.recommended_priority == 'High'
        ]
        if not high_priority:
            return []

        top = high_priority[0]
        return [NotificationCandidate(
            event_type="feature_discovery",
            title="Untapped Content Opportunity",
            body=(
                f"'{top.topic.title()}' has high engagement "
                f"(avg {top.engagement_rate:.0f}) but only {top.creator_count} "
                f"creators covering it. Check the whitespace analysis."
            ),
            deduplication_key=f"feature_whitespace_{top.opportunity_id}",
            magnitude_score=min(1.0, top.opportunity_score / 1000.0),
            actionability_score=0.5,
        )]

    # -- Value Scoring --

    def _score(
        self,
        candidate: NotificationCandidate,
        watched_ids: set,
    ) -> NotificationItem:
        # Relevance
        relevance = candidate.relevance_score
        if relevance == 0:
            if candidate.related_creator_id and candidate.related_creator_id in watched_ids:
                relevance = 1.0
            elif candidate.related_creator_id:
                relevance = 0.5
            else:
                relevance = 0.6

        # Novelty
        last_similar = None
        for item in reversed(self.history.items):
            if item.event_type == candidate.event_type:
                last_similar = item
                break

        if last_similar and last_similar.created_at:
            hours_since = (datetime.now() - last_similar.created_at).total_seconds() / 3600
            cooldown = COOLDOWN_HOURS.get(candidate.event_type, 24)
            novelty = min(1.0, hours_since / cooldown)
        else:
            novelty = 1.0

        value_score = (
            candidate.magnitude_score * 0.30 +
            novelty * 0.25 +
            relevance * 0.25 +
            candidate.actionability_score * 0.20
        )

        return NotificationItem(
            notification_id=f"notif_{datetime.now().strftime('%Y%m%d%H%M%S')}_{id(candidate)}",
            event_type=candidate.event_type,
            title=candidate.title,
            body=candidate.body,
            value_score=value_score,
            created_at=datetime.now(),
            related_creator_id=candidate.related_creator_id,
            related_post_id=candidate.related_post_id,
            deduplication_key=candidate.deduplication_key,
            magnitude_score=candidate.magnitude_score,
            novelty_score=novelty,
            relevance_score=relevance,
            actionability_score=candidate.actionability_score,
        )

    # -- Rate Limiting --

    def _daily_budget_remaining(self) -> int:
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        today_count = sum(
            1 for item in self.history.items
            if item.created_at and item.created_at >= today_start
        )
        return max(0, self.preferences.max_notifications_per_day - today_count)

    def _is_in_cooldown(self, event_type: str) -> bool:
        cooldown = COOLDOWN_HOURS.get(event_type, 24)
        for item in reversed(self.history.items):
            if item.event_type == event_type and item.created_at:
                hours_since = (datetime.now() - item.created_at).total_seconds() / 3600
                return hours_since < cooldown
        return False

    def _is_duplicate(self, item: NotificationItem) -> bool:
        cutoff = datetime.now() - timedelta(hours=24)
        return any(
            existing.deduplication_key == item.deduplication_key
            and existing.created_at
            and existing.created_at >= cutoff
            for existing in self.history.items
        )

    # -- Snapshot Updates --

    def _update_snapshots(
        self,
        rankings: List[Dict[str, Any]],
        summary: Dict[str, Any],
    ):
        self.history.previous_creator_scores = {
            r['creator_id']: r.get('composite_score', 0)
            for r in rankings
        }
        self.history.previous_growth_rates = {
            r['creator_id']: r.get('growth_rate_30d', 0)
            for r in rankings
        }
        self.history.previous_avg_engagement_rate = (
            summary.get('overview', {}).get('average_engagement_rate', 0)
        )
        self.history.last_updated = datetime.now()

    # -- Persistence --

    def _load_history(self) -> NotificationHistory:
        path = Path(self.history_path)
        if not path.exists():
            return NotificationHistory()
        try:
            with open(path) as f:
                data = json.load(f)
            items = []
            for item_data in data.get('items', []):
                items.append(NotificationItem(
                    notification_id=item_data.get('notification_id', ''),
                    event_type=item_data.get('event_type', ''),
                    title=item_data.get('title', ''),
                    body=item_data.get('body', ''),
                    value_score=item_data.get('value_score', 0),
                    created_at=(
                        datetime.fromisoformat(item_data['created_at'])
                        if item_data.get('created_at') else datetime.now()
                    ),
                    is_read=item_data.get('is_read', False),
                    deduplication_key=item_data.get('deduplication_key', ''),
                    related_creator_id=item_data.get('related_creator_id'),
                    related_post_id=item_data.get('related_post_id'),
                ))
            return NotificationHistory(
                items=items,
                last_updated=(
                    datetime.fromisoformat(data['last_updated'])
                    if data.get('last_updated') else None
                ),
                previous_creator_scores=data.get('previous_creator_scores', {}),
                previous_growth_rates=data.get('previous_growth_rates', {}),
                previous_avg_engagement_rate=data.get('previous_avg_engagement_rate', 0),
            )
        except (json.JSONDecodeError, KeyError, ValueError):
            return NotificationHistory()

    def _save_history(self):
        path = Path(self.history_path)
        data = {
            'items': [
                {
                    'notification_id': item.notification_id,
                    'event_type': item.event_type,
                    'title': item.title,
                    'body': item.body,
                    'value_score': item.value_score,
                    'created_at': item.created_at.isoformat() if item.created_at else None,
                    'is_read': item.is_read,
                    'deduplication_key': item.deduplication_key,
                    'related_creator_id': item.related_creator_id,
                    'related_post_id': item.related_post_id,
                }
                for item in self.history.items[-100:]  # Keep last 100
            ],
            'last_updated': (
                self.history.last_updated.isoformat()
                if self.history.last_updated else None
            ),
            'previous_creator_scores': self.history.previous_creator_scores,
            'previous_growth_rates': self.history.previous_growth_rates,
            'previous_avg_engagement_rate': self.history.previous_avg_engagement_rate,
        }
        with open(path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
