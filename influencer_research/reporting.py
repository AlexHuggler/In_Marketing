"""
Reporting Module

Generates actionable reports and exports from influencer research data:
- Executive summary reports
- Detailed analytics exports
- Collaboration target lists
- Content idea templates
- CSV/Excel exports for decision-making
"""

from datetime import datetime
from typing import List, Dict, Any, Optional
import json
from pathlib import Path

try:
    import pandas as pd
    PANDAS_AVAILABLE = True
except ImportError:
    PANDAS_AVAILABLE = False

from .models import (
    Post, Creator, ContentTaxonomy, TrendingTopic,
    WhitespaceOpportunity, CollaborationTarget
)
from .analytics import (
    EngagementAnalyzer, TrendAnalyzer,
    ContentPatternAnalyzer, WhitespaceAnalyzer, CollaborationAnalyzer
)
from .sentiment import EngagementQualityAnalyzer


class ReportGenerator:
    """
    Generates comprehensive reports for actionable decision-making.

    All reports focus on actionability - providing specific recommendations
    rather than just data dumps.
    """

    def __init__(
        self,
        posts: List[Post],
        creators: Dict[str, Creator],
        target_niches: Optional[List[str]] = None
    ):
        self.posts = posts
        self.creators = creators
        self.target_niches = target_niches or []

        # Initialize analyzers
        self.engagement_analyzer = EngagementAnalyzer(posts, creators)
        self.trend_analyzer = TrendAnalyzer(posts)
        self.trend_analyzer.set_engagement_analyzer(self.engagement_analyzer)
        self.pattern_analyzer = ContentPatternAnalyzer(posts)
        self.whitespace_analyzer = WhitespaceAnalyzer(posts, creators)
        self.quality_analyzer = EngagementQualityAnalyzer(posts)

        if target_niches:
            self.collab_analyzer = CollaborationAnalyzer(creators, target_niches)
        else:
            self.collab_analyzer = None

    def generate_executive_summary(self) -> Dict[str, Any]:
        """
        Generate high-level executive summary.

        Provides key insights and recommendations at a glance.
        """
        # Get top-level metrics
        total_posts = len(self.posts)
        total_creators = len(self.creators)

        # Calculate average engagement rate
        if self.posts:
            engagement_rates = [self.engagement_analyzer.calculate_engagement_rate(p) for p in self.posts]
            avg_engagement = sum(engagement_rates) / len(engagement_rates)
            top_engagement = max(engagement_rates)
        else:
            avg_engagement = 0
            top_engagement = 0

        # Get top performers
        top_creators = self.engagement_analyzer.rank_creators_by_engagement()[:5]
        fastest_growing = self.engagement_analyzer.identify_fastest_growing()[:5]
        top_hashtags = self.trend_analyzer.analyze_hashtag_performance()[:5]
        trending_topics = self.trend_analyzer.identify_trending_topics()[:5]

        # Get content insights
        winning_formulas = self.pattern_analyzer.identify_winning_formulas()[:3]
        whitespace = self.whitespace_analyzer.identify_whitespace_opportunities()[:3]

        return {
            'report_date': datetime.now().isoformat(),
            'overview': {
                'total_posts_analyzed': total_posts,
                'total_creators_tracked': total_creators,
                'average_engagement_rate': round(avg_engagement, 2),
                'top_engagement_rate': round(top_engagement, 2),
            },
            'top_creators_by_engagement': [
                {
                    'name': c.display_name or c.username,
                    'platform': c.platform.value,
                    'followers': c.follower_count,
                    'engagement_rate': round(m['avg_engagement_rate'], 2),
                    'tier': c.get_tier(),
                }
                for c, m in top_creators
            ],
            'fastest_growing_creators': [
                {
                    'name': c.display_name or c.username,
                    'growth_rate': round(g, 1),
                    'followers': c.follower_count,
                }
                for c, g in fastest_growing
            ],
            'top_hashtags': [
                {
                    'hashtag': h['hashtag'],
                    'avg_engagement': round(h['avg_engagement'], 0),
                    'post_count': h['post_count'],
                }
                for h in top_hashtags
            ],
            'trending_topics': [
                {
                    'topic': t.topic,
                    'growth_rate': round(t.growth_rate, 1),
                    'post_count': t.post_count,
                }
                for t in trending_topics
            ],
            'winning_content_formulas': [
                {
                    'formula': f.name,
                    'description': f.get_formula_description(),
                    'success_rate': round(f.success_rate, 1),
                    'avg_engagement': round(f.avg_engagement_rate, 0),
                }
                for f in winning_formulas
            ],
            'whitespace_opportunities': [
                {
                    'topic': w.topic,
                    'opportunity_score': round(w.opportunity_score, 1),
                    'creator_count': w.creator_count,
                    'priority': w.recommended_priority,
                }
                for w in whitespace
            ],
            'key_recommendations': self._generate_recommendations(),
        }

    def _generate_recommendations(self) -> List[str]:
        """Generate actionable recommendations based on analysis."""
        recommendations = []

        # Content timing recommendation
        timing = self.trend_analyzer.analyze_timing_performance()
        if timing['best_days']:
            best_day = timing['best_days'][0]
            recommendations.append(
                f"Post on {best_day['day']}s for highest engagement "
                f"({best_day['avg_engagement']:.0f} avg engagement)"
            )

        if timing['best_hours']:
            best_hour = timing['best_hours'][0]
            recommendations.append(
                f"Best posting time: {best_hour['hour']} "
                f"({best_hour['avg_engagement']:.0f} avg engagement)"
            )

        # Content format recommendation
        patterns = self.pattern_analyzer.analyze_pattern_performance()
        if patterns['hooks']:
            best_hook = patterns['hooks'][0]
            recommendations.append(
                f"Use '{best_hook['hook']}' hooks for best results "
                f"({best_hook['avg_engagement']:.0f} avg engagement)"
            )

        # Whitespace recommendation
        whitespace = self.whitespace_analyzer.identify_whitespace_opportunities()
        if whitespace:
            top_opp = whitespace[0]
            recommendations.append(
                f"Consider creating content about '{top_opp.topic}' - "
                f"high engagement ({top_opp.engagement_rate:.0f}) with only "
                f"{top_opp.creator_count} creators covering it"
            )

        # Hashtag recommendation
        top_hashtags = self.trend_analyzer.analyze_hashtag_performance()
        if top_hashtags:
            top_3 = [h['hashtag'] for h in top_hashtags[:3]]
            recommendations.append(
                f"Use high-performing hashtags: {', '.join(top_3)}"
            )

        return recommendations

    def generate_creator_rankings_report(self) -> List[Dict[str, Any]]:
        """
        Generate detailed creator rankings report.

        Ranks by engagement QUALITY, not just followers.
        Key insight: Niche alignment matters more than scale.
        """
        rankings = []

        for creator in self.creators.values():
            metrics = self.engagement_analyzer.calculate_creator_metrics(creator)
            quality = self.quality_analyzer.analyze_creator_engagement_quality(creator.creator_id)

            # Calculate composite score
            composite_score = (
                metrics['avg_engagement_rate'] * 10 +  # Engagement weight
                quality.get('avg_authenticity', 50) * 0.3 +  # Authenticity
                quality.get('community_score', 0) * 0.2 +  # Community
                min(creator.follower_growth_rate_30d, 50) * 0.5  # Growth (capped)
            )

            rankings.append({
                'creator_id': creator.creator_id,
                'username': creator.username,
                'display_name': creator.display_name,
                'platform': creator.platform.value,
                'tier': creator.get_tier(),
                'follower_count': creator.follower_count,
                'primary_niche': creator.primary_niche,
                'all_niches': ', '.join(creator.niche_tags),

                # Engagement metrics
                'avg_engagement_rate': round(metrics['avg_engagement_rate'], 2),
                'best_engagement_rate': round(metrics.get('best_engagement_rate', 0), 2),
                'consistency_score': round(metrics.get('consistency_score', 0), 1),

                # Growth metrics
                'growth_rate_7d': round(creator.follower_growth_rate_7d, 2),
                'growth_rate_30d': round(creator.follower_growth_rate_30d, 2),

                # Quality metrics
                'authenticity_score': round(quality.get('avg_authenticity', 0), 1),
                'community_score': round(quality.get('community_score', 0), 1),
                'comment_quality': round(quality.get('avg_comment_quality', 0), 1),

                # Composite score
                'composite_score': round(composite_score, 1),

                # Posts analyzed
                'posts_analyzed': metrics['total_posts'],
            })

        return sorted(rankings, key=lambda x: x['composite_score'], reverse=True)

    def generate_content_ideas_report(self) -> List[Dict[str, Any]]:
        """
        Generate content idea templates based on winning patterns.

        Provides actionable content frameworks to replicate success.
        """
        ideas = []

        # Get winning formulas
        formulas = self.pattern_analyzer.identify_winning_formulas()

        for formula in formulas[:10]:
            # Get example posts for this formula
            example_posts = [
                p for p in self.posts if p.post_id in formula.example_posts
            ]

            idea = {
                'formula_name': formula.name,
                'description': formula.description,
                'hook_type': formula.hook_types[0].value if formula.hook_types else 'N/A',
                'format': formula.formats[0].value if formula.formats else 'N/A',
                'themes': formula.themes,
                'success_rate': round(formula.success_rate, 1),
                'avg_engagement': round(formula.avg_engagement_rate, 0),
                'posts_using_formula': formula.total_posts_analyzed,
                'template': self._generate_content_template(formula),
                'example_posts': [
                    {
                        'text_preview': p.text[:150] + '...' if len(p.text) > 150 else p.text,
                        'engagement': p.metrics.calculate_total_engagements(),
                    }
                    for p in example_posts[:2]
                ],
            }
            ideas.append(idea)

        # Add whitespace-based ideas
        whitespace = self.whitespace_analyzer.identify_whitespace_opportunities()
        for opp in whitespace[:5]:
            ideas.append({
                'formula_name': f"Whitespace: {opp.topic.title()}",
                'description': f"Underserved topic with high engagement potential",
                'hook_type': opp.suggested_hooks[0].value if opp.suggested_hooks else 'how_to',
                'format': opp.suggested_formats[0].value if opp.suggested_formats else 'educational',
                'themes': [opp.topic],
                'success_rate': 0,  # New territory
                'avg_engagement': round(opp.engagement_rate, 0),
                'posts_using_formula': 0,
                'template': '\n'.join(opp.example_angles),
                'is_whitespace_opportunity': True,
                'opportunity_score': round(opp.opportunity_score, 1),
            })

        return ideas

    def _generate_content_template(self, formula: ContentTaxonomy) -> str:
        """Generate a content template based on formula patterns."""
        hook = formula.hook_types[0] if formula.hook_types else None
        themes = formula.themes

        templates = {
            'question': f"[Ask engaging question about {', '.join(themes)}]\n\nHere's what I've learned...\n\n[3-5 key points]\n\nWhat do you think? Drop your thoughts below!",
            'listicle': f"[Number] {', '.join(themes)} tips that will change your [outcome]:\n\n1. [Tip 1]\n2. [Tip 2]\n3. [Tip 3]\n...\n\nWhich one are you trying first?",
            'how_to': f"How to [achieve goal] with {', '.join(themes)}:\n\nStep 1: [Action]\nStep 2: [Action]\nStep 3: [Action]\n\nSave this for later!",
            'controversial': f"Hot take: [Controversial opinion about {', '.join(themes)}]\n\nHere's why I believe this...\n\n[Supporting points]\n\nAgree or disagree?",
            'story': f"Story time: [Personal experience with {', '.join(themes)}]\n\n[Beginning]\n[Challenge]\n[Resolution]\n[Lesson learned]\n\nHas this happened to you?",
            'data_insight': f"[Surprising statistic about {', '.join(themes)}]\n\nHere's what this means for you:\n\n[3 implications]\n\nShare if this surprised you!",
            'personal_experience': f"My {', '.join(themes)} journey:\n\n[Where I started]\n[What I learned]\n[Where I am now]\n\nWhat's your story?",
        }

        if hook and hook.value in templates:
            return templates[hook.value]
        return f"Create content about {', '.join(themes)} using a {hook.value if hook else 'engaging'} approach"

    def generate_collaboration_targets_report(self) -> List[Dict[str, Any]]:
        """
        Generate collaboration target recommendations.

        Prioritizes niche alignment over follower count.
        """
        if not self.collab_analyzer:
            # Fall back to engagement-based ranking
            rankings = self.engagement_analyzer.rank_creators_by_engagement()
            return [
                {
                    'creator_id': c.creator_id,
                    'name': c.display_name or c.username,
                    'platform': c.platform.value,
                    'followers': c.follower_count,
                    'engagement_rate': round(m['avg_engagement_rate'], 2),
                    'tier': c.get_tier(),
                    'niches': ', '.join(c.niche_tags),
                    'fit_score': round(m['avg_engagement_rate'] * 10, 1),
                    'recommendation': 'Based on engagement rate (set target_niches for alignment scoring)',
                }
                for c, m in rankings[:20]
            ]

        # Use collaboration analyzer for niche-aligned recommendations
        targets = self.collab_analyzer.find_collaboration_targets()

        return [
            {
                'creator_id': t.creator_id,
                'name': t.creator_name,
                'platform': t.platform.value,
                'followers': t.follower_count,
                'engagement_rate': round(t.engagement_rate, 2),
                'growth_rate': round(t.growth_rate, 2),
                'niche_alignment_score': round(t.niche_alignment_score, 1),
                'engagement_quality_score': round(t.engagement_quality_score, 1),
                'overall_fit_score': round(t.overall_fit_score, 1),
                'recommendation': self._get_collab_recommendation(t),
            }
            for t in targets[:20]
        ]

    def _get_collab_recommendation(self, target: CollaborationTarget) -> str:
        """Generate collaboration recommendation text."""
        if target.overall_fit_score >= 70:
            return "Highly recommended - strong niche alignment and engagement"
        elif target.overall_fit_score >= 50:
            return "Good fit - consider for campaign"
        elif target.overall_fit_score >= 30:
            return "Potential fit - review content manually"
        else:
            return "Lower priority - limited alignment"

    def generate_trending_report(self) -> Dict[str, Any]:
        """Generate comprehensive trending analysis report."""
        hashtags = self.trend_analyzer.analyze_hashtag_performance()
        topics = self.trend_analyzer.analyze_topic_performance()
        trending = self.trend_analyzer.identify_trending_topics()
        timing = self.trend_analyzer.analyze_timing_performance()

        return {
            'top_hashtags': hashtags[:20],
            'top_topics': topics[:20],
            'trending_now': [
                {
                    'topic': t.topic,
                    'growth_rate': round(t.growth_rate, 1),
                    'post_count': t.post_count,
                    'avg_engagement': round(t.avg_engagement_rate, 0),
                }
                for t in trending[:20]
            ],
            'best_posting_times': {
                'by_day': timing['best_days'],
                'by_hour': timing['best_hours'],
            },
        }

    def export_to_csv(self, output_dir: str = "./reports"):
        """Export all reports to CSV files for actionable use."""
        if not PANDAS_AVAILABLE:
            print("pandas not available - cannot export to CSV")
            return

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Export creator rankings
        creator_data = self.generate_creator_rankings_report()
        if creator_data:
            df = pd.DataFrame(creator_data)
            df.to_csv(output_path / f"creator_rankings_{timestamp}.csv", index=False)
            print(f"Exported: creator_rankings_{timestamp}.csv")

        # Export content ideas
        ideas_data = self.generate_content_ideas_report()
        if ideas_data:
            df = pd.DataFrame(ideas_data)
            df.to_csv(output_path / f"content_ideas_{timestamp}.csv", index=False)
            print(f"Exported: content_ideas_{timestamp}.csv")

        # Export collaboration targets
        collab_data = self.generate_collaboration_targets_report()
        if collab_data:
            df = pd.DataFrame(collab_data)
            df.to_csv(output_path / f"collaboration_targets_{timestamp}.csv", index=False)
            print(f"Exported: collaboration_targets_{timestamp}.csv")

        # Export trending data
        trending = self.generate_trending_report()
        if trending.get('top_hashtags'):
            df = pd.DataFrame(trending['top_hashtags'])
            df.to_csv(output_path / f"top_hashtags_{timestamp}.csv", index=False)
            print(f"Exported: top_hashtags_{timestamp}.csv")

        if trending.get('trending_now'):
            df = pd.DataFrame(trending['trending_now'])
            df.to_csv(output_path / f"trending_topics_{timestamp}.csv", index=False)
            print(f"Exported: trending_topics_{timestamp}.csv")

        # Export executive summary as JSON
        summary = self.generate_executive_summary()
        with open(output_path / f"executive_summary_{timestamp}.json", 'w') as f:
            json.dump(summary, f, indent=2, default=str)
        print(f"Exported: executive_summary_{timestamp}.json")

        print(f"\nAll reports exported to: {output_path}")

    def export_to_excel(self, output_path: str = "./reports/influencer_research.xlsx"):
        """Export all reports to a single Excel workbook with multiple sheets."""
        if not PANDAS_AVAILABLE:
            print("pandas not available - cannot export to Excel")
            return

        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
            # Creator rankings
            creator_data = self.generate_creator_rankings_report()
            if creator_data:
                pd.DataFrame(creator_data).to_excel(
                    writer, sheet_name='Creator Rankings', index=False
                )

            # Content ideas
            ideas_data = self.generate_content_ideas_report()
            if ideas_data:
                pd.DataFrame(ideas_data).to_excel(
                    writer, sheet_name='Content Ideas', index=False
                )

            # Collaboration targets
            collab_data = self.generate_collaboration_targets_report()
            if collab_data:
                pd.DataFrame(collab_data).to_excel(
                    writer, sheet_name='Collaboration Targets', index=False
                )

            # Trending data
            trending = self.generate_trending_report()
            if trending.get('top_hashtags'):
                pd.DataFrame(trending['top_hashtags']).to_excel(
                    writer, sheet_name='Top Hashtags', index=False
                )

            if trending.get('trending_now'):
                pd.DataFrame(trending['trending_now']).to_excel(
                    writer, sheet_name='Trending Topics', index=False
                )

            # Best posting times
            if trending.get('best_posting_times'):
                pd.DataFrame(trending['best_posting_times']['by_day']).to_excel(
                    writer, sheet_name='Best Days', index=False
                )
                pd.DataFrame(trending['best_posting_times']['by_hour']).to_excel(
                    writer, sheet_name='Best Hours', index=False
                )

        print(f"Excel report exported to: {output_path}")

    def print_summary(self):
        """Print a formatted summary to console."""
        summary = self.generate_executive_summary()

        print("\n" + "=" * 60)
        print("INFLUENCER RESEARCH EXECUTIVE SUMMARY")
        print("=" * 60)
        print(f"\nReport Date: {summary['report_date']}")

        print("\n--- OVERVIEW ---")
        overview = summary['overview']
        print(f"Posts Analyzed: {overview['total_posts_analyzed']}")
        print(f"Creators Tracked: {overview['total_creators_tracked']}")
        print(f"Average Engagement Rate: {overview['average_engagement_rate']}%")
        print(f"Top Engagement Rate: {overview['top_engagement_rate']}%")

        print("\n--- TOP CREATORS BY ENGAGEMENT ---")
        for i, c in enumerate(summary['top_creators_by_engagement'], 1):
            print(f"{i}. {c['name']} ({c['platform']}) - {c['engagement_rate']}% engagement, {c['followers']:,} followers")

        print("\n--- FASTEST GROWING ---")
        for i, c in enumerate(summary['fastest_growing_creators'], 1):
            print(f"{i}. {c['name']} - {c['growth_rate']}% engagement growth")

        print("\n--- TOP HASHTAGS ---")
        for h in summary['top_hashtags']:
            print(f"  {h['hashtag']} - {h['avg_engagement']:.0f} avg engagement ({h['post_count']} posts)")

        print("\n--- TRENDING TOPICS ---")
        for t in summary['trending_topics']:
            print(f"  {t['topic']} - {t['growth_rate']}% growth ({t['post_count']} posts)")

        print("\n--- WINNING CONTENT FORMULAS ---")
        for f in summary['winning_content_formulas']:
            print(f"  {f['formula']} - {f['success_rate']}% success rate")

        print("\n--- WHITESPACE OPPORTUNITIES ---")
        for w in summary['whitespace_opportunities']:
            print(f"  {w['topic']} - Score: {w['opportunity_score']}, Priority: {w['priority']}")

        print("\n--- KEY RECOMMENDATIONS ---")
        for i, rec in enumerate(summary['key_recommendations'], 1):
            print(f"{i}. {rec}")

        print("\n" + "=" * 60)
