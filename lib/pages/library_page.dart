import 'package:flutter/material.dart';
import 'package:fyp_musicapp_aws/widgets/section_title.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = screenSize.width * 0.04;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Music Library'),
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SectionTitle(title: 'Genre'),
                SizedBox(height: padding),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: padding,
                    mainAxisSpacing: padding,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final categories = ['Pop', 'Rock', 'Jazz', 'Classical'];
                    final colors = [
                      Colors.blue,
                      Colors.red,
                      Colors.green,
                      Colors.purple
                    ];
                    return Container(
                      decoration: BoxDecoration(
                        color: colors[index].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          categories[index],
                          style: TextStyle(
                            fontSize: screenSize.width * 0.045,
                            fontWeight: FontWeight.bold,
                            color: colors[index],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Add more sections for the library page here
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
