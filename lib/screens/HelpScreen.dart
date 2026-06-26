import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // About Us Section
          Text(
            'About Us',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'The pandemic inspired us to create EleFit, a one-stop shop for fitness gear. We aim to simplify your shopping experience by offering high-quality gym equipment, outdoor gear, and solutions for all ages. Our goal is to be your trusted destination for innovative products to enhance your well-being and fitness journey.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Our Ethos Section
          Text(
            'Our Ethos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Where Fitness Meets Focus',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover EleFit, where our values guide our journey. We\'re committed to crafting superior products through innovation, transparency, and trust. Empowering you to achieve your fitness goals is our priority, while we also strive to minimize our environmental impact through sustainable practices. Join us as we embark on this journey together towards a healthier and more sustainable future.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Community Section
          Text(
            'Through the Power of Community! Advances Toward a Better World for All',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Empower & Innovate',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'EleFit welcomes you to our vibrant EleFitFam community, embracing your commitment to health and fitness. Immerse yourself in our positive, uplifting environment, where motivation and empowerment fuel your journey towards achieving your goals. Join EleFit today to connect with fellow enthusiasts, sharing your passion for an active lifestyle and embarking on a transformative path of self-improvement and empowerment.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Blog Posts Section
          Text(
            'Blog Posts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          _buildBlogPostCard(
            context,
            title: 'Show Up Ready — The EleFit Way',
            content:
                'Preparation is the key to peak performance—in fitness and in life. This post shares how being organized and equipped can help you achieve more with less stress. Learn why EleFit believes in “sharpening the saw” and how the right tools can help you create lasting memories, reach your goals, and spend more time on what truly matters.',
          ),
          const SizedBox(height: 16),
          _buildBlogPostCard(
            context,
            title: 'A Happy and Active Family',
            content:
                'In this heartfelt post, EleFit founder Sudheera Vanam shares a personal journey of transformation—fueled by family, purpose, and a passion for fitness. From shifting priorities to making meaningful sacrifices, this story is a reminder that fitness is more than a lifestyle—it’s a legacy we build for the next generation. Join the movement to live intentionally, stay strong, and raise our children with purpose.',
          ),
        ],
      ),
    );
  }

  Widget _buildBlogPostCard(BuildContext context, {required String title, required String content}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}