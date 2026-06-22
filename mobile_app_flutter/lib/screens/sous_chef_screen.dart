import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';

class SousChefScreen extends StatefulWidget {
  final String? recipeId;
  final String? recipeTitle;
  const SousChefScreen({super.key, this.recipeId, this.recipeTitle});

  @override
  State<SousChefScreen> createState() => _SousChefScreenState();
}

class _SousChefScreenState extends State<SousChefScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipeTitle != null) {
      _messages.add(ChatMessage(
        text: 'Hi! I\'m your Sous Chef AI. I\'m ready to help you cook "${widget.recipeTitle}". Ask me anything — steps, substitutions, timing, or tips!',
        isUser: false,
      ));
    } else {
      _messages.add(ChatMessage(
        text: 'Hi! I\'m your Sous Chef AI. Ask me anything about cooking, recipes, or nutrition!',
        isUser: false,
      ));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Last 6 turns as history (skip SEARCH recipe-card messages, they have no text to replay)
    final history = _messages
        .where((m) => m.type != 'SEARCH')
        .toList()
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((m) => <String, String>{
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final result = await _api.sendChatMessage(text, currentRecipeId: widget.recipeId, history: history);

    if (!mounted) return;
    if (result['success'] == true) {
      final msg = ChatMessage.fromAiResponse(result['data']);
      setState(() { _messages.add(msg); _sending = false; });
    } else {
      setState(() {
        _messages.add(ChatMessage(text: result['message'] ?? 'Something went wrong.', isUser: false));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sous Chef AI', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
          if (widget.recipeTitle != null)
            Text(widget.recipeTitle!, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (_sending && i == _messages.length) return _TypingBubble();
                final msg = _messages[i];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask anything about cooking…',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16, backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.restaurant_menu_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? theme.colorScheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14, height: 1.4,
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          if (!isUser && message.recipes.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: message.recipes.length,
                itemBuilder: (_, i) => _MiniRecipeCard(recipe: message.recipes[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniRecipeCard extends StatelessWidget {
  final Recipe recipe;
  const _MiniRecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: recipe.imageUrl.isNotEmpty
                ? Image.network(recipe.imageUrl, height: 90, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 90, color: Colors.grey[200], child: const Icon(Icons.restaurant_rounded, color: Colors.grey)))
                : Container(height: 90, color: Colors.grey[200], child: const Icon(Icons.restaurant_rounded, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(recipe.title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.restaurant_menu_rounded, size: 16, color: Colors.white)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0), _Dot(delay: 200), _Dot(delay: 400),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: FadeTransition(
      opacity: _anim,
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
    ),
  );
}
