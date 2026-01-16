"""
Sample Data Generator

Creates realistic sample data for demonstrating the influencer research tool.
Use this to test the system before loading real data.
"""

import random
from datetime import datetime, timedelta
from typing import List, Dict

from .models import (
    Post, Creator, Comment, EngagementMetrics,
    Platform, MediaType, CreatorGrowthMetrics
)


def generate_sample_data(
    num_creators: int = 25,
    posts_per_creator: int = 15,
    comments_per_post: int = 10
) -> tuple[List[Post], Dict[str, Creator]]:
    """
    Generate realistic sample data for testing.

    Returns (posts, creators_dict)
    """
    # Define niches with realistic engagement patterns
    NICHES = {
        'productivity': {'base_eng': 3.5, 'volatility': 0.3},
        'technology': {'base_eng': 2.8, 'volatility': 0.4},
        'ai': {'base_eng': 4.2, 'volatility': 0.5},
        'marketing': {'base_eng': 3.0, 'volatility': 0.3},
        'entrepreneurship': {'base_eng': 3.8, 'volatility': 0.35},
        'personal-finance': {'base_eng': 4.0, 'volatility': 0.4},
        'wellness': {'base_eng': 4.5, 'volatility': 0.25},
        'fitness': {'base_eng': 5.2, 'volatility': 0.3},
        'cooking': {'base_eng': 4.8, 'volatility': 0.2},
        'travel': {'base_eng': 4.0, 'volatility': 0.35},
        'fashion': {'base_eng': 3.5, 'volatility': 0.3},
        'photography': {'base_eng': 3.2, 'volatility': 0.25},
        'design': {'base_eng': 3.0, 'volatility': 0.3},
        'leadership': {'base_eng': 3.5, 'volatility': 0.35},
        'career': {'base_eng': 4.0, 'volatility': 0.3},
    }

    PLATFORMS = [Platform.INSTAGRAM, Platform.TIKTOK, Platform.TWITTER, Platform.LINKEDIN]

    # Content templates for realistic posts
    CONTENT_TEMPLATES = [
        # Question hooks
        ("What's the one {topic} hack that changed your life?", MediaType.TEXT, 'question'),
        ("How do you handle {challenge} in your {topic} journey?", MediaType.TEXT, 'question'),
        # Listicles
        ("5 {topic} tips that doubled my {outcome}:", MediaType.CAROUSEL, 'listicle'),
        ("7 mistakes I made in {topic} (and how to avoid them)", MediaType.REEL, 'listicle'),
        ("10 {topic} tools I can't live without", MediaType.IMAGE, 'listicle'),
        # How-to
        ("How to master {topic} in 30 days:", MediaType.VIDEO, 'how_to'),
        ("Step-by-step guide to {outcome}", MediaType.CAROUSEL, 'how_to'),
        ("The complete beginner's guide to {topic}", MediaType.ARTICLE, 'how_to'),
        # Controversial
        ("Hot take: Most {topic} advice is wrong", MediaType.TEXT, 'controversial'),
        ("Unpopular opinion: {topic} is overrated", MediaType.VIDEO, 'controversial'),
        # Story
        ("My {topic} journey: From zero to {outcome}", MediaType.REEL, 'story'),
        ("How I went from {start} to {end} in {topic}", MediaType.VIDEO, 'story'),
        # Data
        ("{percentage}% of people fail at {topic}. Here's why:", MediaType.IMAGE, 'data'),
        ("I analyzed 1000 {topic} posts. Here's what works:", MediaType.CAROUSEL, 'data'),
        # Personal
        ("What I wish I knew about {topic} 5 years ago", MediaType.TEXT, 'personal'),
        ("My morning {topic} routine that changed everything", MediaType.REEL, 'personal'),
    ]

    FIRST_NAMES = [
        'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Jamie', 'Avery',
        'Quinn', 'Reese', 'Skyler', 'Dakota', 'Cameron', 'Peyton', 'Blake',
        'Emma', 'Liam', 'Sophia', 'Noah', 'Olivia', 'James', 'Ava', 'William',
        'Isabella', 'Oliver'
    ]

    LAST_NAMES = [
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
        'Davis', 'Rodriguez', 'Martinez', 'Chen', 'Lee', 'Wang', 'Kim', 'Patel',
        'Anderson', 'Taylor', 'Thomas', 'Moore', 'Jackson', 'White', 'Harris'
    ]

    COMMENT_TEMPLATES = [
        ("This is exactly what I needed to hear! Thank you!", True),
        ("Great tips! Saving this for later.", True),
        ("Love this content. Keep it coming!", True),
        ("So helpful! I've been struggling with this.", True),
        ("Disagree. This doesn't work in real life.", False),
        ("Not sure about this one...", False),
        ("Can you elaborate on point 3?", True),
        ("This changed my perspective completely.", True),
        ("Where can I learn more about this?", True),
        ("Sharing with my team!", True),
        ("Game changer!", True),
        ("I tried this and it actually works!", True),
        ("Overrated advice tbh", False),
        ("Anyone else think this is oversimplified?", False),
        ("Finally someone talking about this!", True),
        ("Your content is always so valuable", True),
        ("Bookmarked!", True),
        ("This is why I follow you", True),
        ("fire content", True),
        ("nice", True),
        ("W", True),
    ]

    creators = {}
    posts = []

    # Generate creators
    for i in range(num_creators):
        creator_id = f"creator_{i:03d}"
        first_name = random.choice(FIRST_NAMES)
        last_name = random.choice(LAST_NAMES)

        # Assign 1-3 niches
        creator_niches = random.sample(list(NICHES.keys()), random.randint(1, 3))
        primary_niche = creator_niches[0]
        niche_config = NICHES[primary_niche]

        # Generate follower count (logarithmic distribution for realistic tiers)
        tier = random.choices(
            ['nano', 'micro', 'mid', 'macro', 'mega'],
            weights=[30, 35, 20, 12, 3]
        )[0]

        follower_ranges = {
            'nano': (100, 999),
            'micro': (1000, 9999),
            'mid': (10000, 99999),
            'macro': (100000, 999999),
            'mega': (1000000, 5000000),
        }

        follower_count = random.randint(*follower_ranges[tier])

        # Generate platform
        platform = random.choice(PLATFORMS)

        # Generate username
        username_styles = [
            f"{first_name.lower()}{last_name.lower()}",
            f"{first_name.lower()}_{primary_niche}",
            f"the_{primary_niche}_pro",
            f"{first_name.lower()}.{primary_niche}",
            f"{primary_niche}_{first_name.lower()}",
        ]
        username = random.choice(username_styles).replace('-', '')

        # Generate engagement rate based on tier (smaller = higher engagement usually)
        tier_engagement_modifiers = {
            'nano': 1.5,
            'micro': 1.3,
            'mid': 1.0,
            'macro': 0.7,
            'mega': 0.5,
        }

        base_engagement = niche_config['base_eng'] * tier_engagement_modifiers[tier]
        engagement_rate = base_engagement * random.uniform(0.7, 1.3)

        # Generate growth rates
        growth_7d = random.gauss(0.5, 2)  # Can be negative
        growth_30d = random.gauss(2.0, 5)

        creator = Creator(
            creator_id=creator_id,
            username=username,
            platform=platform,
            display_name=f"{first_name} {last_name}",
            bio=f"{primary_niche.title()} enthusiast | Sharing {', '.join(creator_niches)} insights",
            follower_count=follower_count,
            following_count=random.randint(100, min(5000, follower_count)),
            niche_tags=creator_niches,
            primary_niche=primary_niche,
            secondary_niches=creator_niches[1:],
            avg_engagement_rate=engagement_rate,
            avg_likes=int(follower_count * engagement_rate / 100 * 0.7),
            avg_comments=int(follower_count * engagement_rate / 100 * 0.2),
            total_posts=posts_per_creator,
            follower_growth_rate_7d=growth_7d,
            follower_growth_rate_30d=growth_30d,
            first_tracked=datetime.now() - timedelta(days=30),
            last_updated=datetime.now(),
        )

        creators[creator_id] = creator

        # Generate posts for this creator
        for j in range(posts_per_creator):
            post_id = f"post_{creator_id}_{j:03d}"

            # Random timestamp in last 30 days
            timestamp = datetime.now() - timedelta(
                days=random.randint(0, 30),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )

            # Select content template
            template, media_type, hook_type = random.choice(CONTENT_TEMPLATES)

            # Fill in template
            text = template.format(
                topic=primary_niche,
                challenge=random.choice(['consistency', 'motivation', 'time', 'focus']),
                outcome=random.choice(['results', 'productivity', 'success', 'growth']),
                start=random.choice(['beginner', 'struggling', 'confused']),
                end=random.choice(['expert', 'thriving', 'successful']),
                percentage=random.randint(60, 95),
            )

            # Generate hashtags
            hashtags = [f"#{creator_niches[0]}", f"#{random.choice(['tips', 'advice', 'growth', 'success'])}"]
            if len(creator_niches) > 1:
                hashtags.append(f"#{creator_niches[1]}")

            # Generate engagement with variance
            engagement_mult = random.gauss(1.0, niche_config['volatility'])
            engagement_mult = max(0.2, engagement_mult)  # Floor at 20%

            # Platform-specific reach factors
            platform_reach = {
                Platform.TIKTOK: 3.0,  # Higher viral potential
                Platform.INSTAGRAM: 1.0,
                Platform.TWITTER: 0.8,
                Platform.LINKEDIN: 0.6,
            }

            base_views = int(follower_count * platform_reach.get(platform, 1.0) * random.uniform(0.5, 2.0))

            metrics = EngagementMetrics(
                likes=int(base_views * engagement_rate / 100 * 0.7 * engagement_mult),
                comments=int(base_views * engagement_rate / 100 * 0.15 * engagement_mult),
                shares=int(base_views * engagement_rate / 100 * 0.1 * engagement_mult),
                saves=int(base_views * engagement_rate / 100 * 0.05 * engagement_mult),
                views=base_views,
            )

            # Generate comments
            comments = []
            for k in range(min(metrics.comments, comments_per_post)):
                comment_text, is_positive = random.choice(COMMENT_TEMPLATES)
                comment = Comment(
                    comment_id=f"comment_{post_id}_{k:03d}",
                    author_id=f"user_{random.randint(1000, 9999)}",
                    author_username=f"user_{random.randint(1000, 9999)}",
                    text=comment_text,
                    timestamp=timestamp + timedelta(hours=random.randint(1, 48)),
                    likes=random.randint(0, 50),
                    sentiment_score=0.5 if is_positive else -0.3,
                )
                comments.append(comment)

            # Generate velocity metrics
            hours_since = (datetime.now() - timestamp).total_seconds() / 3600
            total_eng = metrics.calculate_total_engagements()

            if hours_since < 1:
                eng_1h = total_eng
                eng_6h = 0
                eng_24h = 0
            elif hours_since < 6:
                eng_1h = int(total_eng * 0.3)
                eng_6h = total_eng
                eng_24h = 0
            elif hours_since < 24:
                eng_1h = int(total_eng * 0.2)
                eng_6h = int(total_eng * 0.6)
                eng_24h = total_eng
            else:
                eng_1h = int(total_eng * 0.15)
                eng_6h = int(total_eng * 0.4)
                eng_24h = int(total_eng * 0.8)

            post = Post(
                post_id=post_id,
                creator_id=creator_id,
                platform=platform,
                text=text,
                media_type=media_type,
                timestamp=timestamp,
                hashtags=hashtags,
                topics=creator_niches,
                metrics=metrics,
                comments_list=comments,
                engagements_1h=eng_1h,
                engagements_6h=eng_6h,
                engagements_24h=eng_24h,
            )

            posts.append(post)
            creator.posts.append(post)

    return posts, creators


def create_sample_csv_files(output_dir: str = "./sample_data"):
    """Create sample CSV files for testing data import."""
    import os
    os.makedirs(output_dir, exist_ok=True)

    # Sample posts CSV
    posts_csv = """post_id,creator_id,platform,text,media_type,timestamp,likes,comments,shares,saves,views,hashtags,topics
p001,c001,instagram,"5 productivity hacks that will change your life! #productivity #tips",image,2024-01-15 10:30:00,1500,89,45,230,15000,"productivity,tips","productivity,self-improvement"
p002,c001,instagram,"Morning routine for maximum focus:",reel,2024-01-16 08:00:00,5200,312,178,890,52000,"morningroutine,wellness","wellness,productivity"
p003,c002,tiktok,"Hot take: Most productivity advice is wrong. Here's what actually works:",video,2024-01-15 14:00:00,28000,1450,2100,3200,280000,"productivity,hottake","productivity,controversial"
p004,c002,tiktok,"How I read 52 books last year (step by step):",video,2024-01-17 09:00:00,45000,2300,3500,8900,450000,"reading,books,learning","learning,productivity"
p005,c003,linkedin,"The #1 mistake people make when starting their business:",text,2024-01-14 11:00:00,890,156,89,120,25000,"entrepreneurship,business","entrepreneurship,startup"
p006,c003,linkedin,"I interviewed 100 successful founders. Here's what they have in common:",article,2024-01-18 07:30:00,2100,445,312,890,67000,"entrepreneurship,success","entrepreneurship,leadership"
p007,c004,twitter,"AI will replace 90% of marketing jobs. Here's why I believe this:",text,2024-01-16 16:00:00,12000,3400,5600,1200,890000,"ai,marketing,future","ai,marketing"
p008,c004,twitter,"Thread: How to use ChatGPT for content creation (10 prompts that work):",thread,2024-01-19 10:00:00,8900,1200,2300,4500,234000,"ai,chatgpt,content","ai,marketing,content"
p009,c005,instagram,"Meal prep Sunday! 5 healthy recipes for the week:",carousel,2024-01-14 12:00:00,3400,234,89,1200,45000,"mealprep,healthy,cooking","cooking,wellness"
p010,c005,instagram,"Why I stopped counting calories (and what I do instead):",reel,2024-01-17 18:00:00,8900,890,456,2300,89000,"nutrition,health,mindset","wellness,nutrition"
"""

    # Sample creators CSV
    creators_csv = """creator_id,username,platform,display_name,follower_count,following_count,bio,niche_tags,avg_engagement_rate,growth_rate_7d,growth_rate_30d,total_posts
c001,productivity_pro,instagram,Sarah Johnson,45000,890,"Helping you work smarter | Productivity coach","productivity,self-improvement",3.8,1.2,4.5,342
c002,the_learning_guy,tiktok,Mike Chen,890000,156,"Making learning fun | 2M learners helped","learning,productivity,education",4.2,2.8,12.3,567
c003,startup_sarah,linkedin,Sarah Williams,125000,1200,"3x founder | Startup advisor | Forbes 30u30","entrepreneurship,startup,business",2.1,0.5,2.1,234
c004,ai_marcus,twitter,Marcus Thompson,234000,890,"AI researcher | Breaking down tech for everyone","ai,technology,marketing",5.1,4.5,18.9,890
c005,healthy_emma,instagram,Emma Davis,67000,445,"Registered dietitian | Sustainable nutrition","nutrition,wellness,cooking",4.8,1.0,3.8,456
"""

    with open(f"{output_dir}/sample_posts.csv", 'w') as f:
        f.write(posts_csv)

    with open(f"{output_dir}/sample_creators.csv", 'w') as f:
        f.write(creators_csv)

    print(f"Sample CSV files created in {output_dir}/")
    print("  - sample_posts.csv")
    print("  - sample_creators.csv")

    return f"{output_dir}/sample_posts.csv", f"{output_dir}/sample_creators.csv"
