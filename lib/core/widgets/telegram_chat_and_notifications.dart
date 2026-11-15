import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../constants/app_colors.dart';
import '../localization/app_localizations.dart';
import '../theme/branding_provider.dart';
import '../utils/number_parser.dart';
import '../../data/local/app_database.dart';

// =============================================================================
// ۱. موتور نوتیفیکیشن زنده درون‌اپ و زنگوله مرکز اعلانات (Smart Notification Center)
// =============================================================================

class MaxGymAppNotification {
  final String id;
  final String title;
  final String body;
  final String category; // 'chat', 'program', 'workout_log', 'system'
  final DateTime createdAt;
  final bool isRead;

  const MaxGymAppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'chat',
    required this.createdAt,
    this.isRead = false,
  });

  MaxGymAppNotification copyWith({bool? isRead}) {
    return MaxGymAppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

final notificationCenterProvider = StateNotifierProvider<
    MaxGymNotificationCenterNotifier, List<MaxGymAppNotification>>((ref) {
  return MaxGymNotificationCenterNotifier();
});

class MaxGymNotificationCenterNotifier
    extends StateNotifier<List<MaxGymAppNotification>> {
  final Set<String> _seenEventIds = {};

  MaxGymNotificationCenterNotifier() : super(const []);

  int get unreadCount => state.where((n) => !n.isRead).length;

  void pushNotification({
    required String eventKey,
    required String title,
    required String body,
    String category = 'chat',
    BuildContext? activeContext,
  }) {
    if (_seenEventIds.contains(eventKey)) return;
    _seenEventIds.add(eventKey);

    HapticFeedback.mediumImpact();
    final item = MaxGymAppNotification(
      id: eventKey,
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
    );
    state = [item, ...state].take(50).toList();

    if (activeContext != null && activeContext.mounted) {
      ScaffoldMessenger.of(activeContext).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 85),
          backgroundColor: const Color(0xFF111714),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF72C832), width: 1.5),
          ),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF72C832).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.bellRing,
                    color: Color(0xFF72C832), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearAll() {
    state = const [];
  }
}

/// ویجت دکمه زنگوله نوتیفیکیشن برای قرارگیری در AppBar پنل مربی و ورزشکار
class MaxGymNotificationBellButton extends ConsumerWidget {
  final bool isFa;
  const MaxGymNotificationBellButton({super.key, this.isFa = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationCenterProvider);
    final unread = notifications.where((n) => !n.isRead).length;
    final primary = Theme.of(context).colorScheme.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: isFa ? 'مرکز اعلانات زنده' : 'Live Notifications',
          icon: Icon(
            unread > 0 ? LucideIcons.bellRing : LucideIcons.bell,
            color: unread > 0 ? primary : Colors.white70,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(notificationCenterProvider.notifier).markAllAsRead();
            _showNotificationSheet(context, ref, isFa);
          },
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationSheet(
      BuildContext context, WidgetRef ref, bool isFa) {
    final list = ref.read(notificationCenterProvider);
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.bellRing, color: primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isFa
                            ? 'مرکز اعلانات زنده MAX GYM'
                            : 'MAX GYM Live Notifications',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  if (list.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(notificationCenterProvider.notifier).clearAll();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(LucideIcons.trash2, size: 15),
                      label: Text(isFa ? 'پاکسازی' : 'Clear'),
                    ),
                ],
              ),
              const Divider(height: 24, color: Colors.white12),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.checkCircle2,
                          size: 44, color: Colors.white24),
                      const SizedBox(height: 10),
                      Text(
                        isFa
                            ? 'هیچ اعلان خوانده‌نشده‌ای ندارید.'
                            : 'All caught up! No new notifications.',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (_, idx) {
                      final n = list[idx];
                      final timeStr =
                          '${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151A17),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primary.withOpacity(0.16),
                            child: Icon(
                              n.category == 'program'
                                  ? LucideIcons.clipboardCheck
                                  : LucideIcons.messageSquare,
                              color: primary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            n.body,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                          trailing: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white38),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// ۲. پیام‌رسان تلگرامی Realtime با هدر آنلاین، تیک دوگانه (✓✓) و ریپلای
// =============================================================================

class MaxGymTelegramChatView extends ConsumerStatefulWidget {
  final AthleteEntity athlete;
  final String currentSenderRole; // 'coach' | 'athlete'

  const MaxGymTelegramChatView({
    super.key,
    required this.athlete,
    required this.currentSenderRole,
  });

  @override
  ConsumerState<MaxGymTelegramChatView> createState() =>
      _MaxGymTelegramChatViewState();
}

class _MaxGymTelegramChatViewState
    extends ConsumerState<MaxGymTelegramChatView> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessageEntity> _messages = [];
  ChatMessageEntity? _replyingToMessage;
  DateTime? _peerLastSeenAt;
  String _peerAvatarB64 = '';
  bool _isPeerOnline = true;

  StreamSubscription<List<Map<String, dynamic>>>? _realtimeChatSub;
  Timer? _rpcChatPollTimer;

  static const List<String> _coachQuickRepliesFa = [
    '🔥 خسته نباشی قهرمان! رکوردت عالی بود',
    '💧 یادت نره امروز حداقل ۳.۵ لیتر آب بخوری',
    '📈 برنامه جدیدت رو ثبت کردم، از تب باشگاه ببین',
    '⚖️ لطفاً وزن ناشتای این هفته‌ات رو برام ثبت کن',
  ];

  static const List<String> _athleteQuickRepliesFa = [
    '💪 استاد تمرین امروز رو کامل انجام دادم و ثبت کردم',
    '🙏 ممنون استاد، برنامه رو دیدم',
    '🔄 استاد برای وعده ناهار می‌تونم جایگزین استفاده کنم؟',
    '⚡ استاد برنامه‌ام رو به اتمامه، لطفاً تمدیدش کنید',
  ];

  @override
  void initState() {
    super.initState();
    _messages = ref
        .read(appDatabaseProvider)
        .getChatMessagesForAthlete(widget.athlete.id);
    _subscribeToRealtimeAndRpcChat();
  }

  @override
  void dispose() {
    _realtimeChatSub?.cancel();
    _rpcChatPollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _fetchChatAndPresenceViaRpc() async {
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null || !mounted) return;
      final db = ref.read(appDatabaseProvider);

      // اگر کاربر فعلی مربی است، پیام‌های شاگرد را در سرور دو تیک (Seen) کند
      if (widget.currentSenderRole == 'coach') {
        unawaited(client.rpc('coach_mark_chat_read',
            params: {'p_athlete_id': widget.athlete.id}));

        final athRow = await client
            .from('athletes')
            .select('last_seen_at, avatar_b64')
            .eq('id', widget.athlete.id)
            .maybeSingle();
        if (athRow != null && mounted) {
          final seenRaw = athRow['last_seen_at'] as String?;
          final seenDt =
              seenRaw != null ? DateTime.tryParse(seenRaw)?.toLocal() : null;
          setState(() {
            _peerLastSeenAt = seenDt;
            _peerAvatarB64 = (athRow['avatar_b64'] as String?) ?? '';
            _isPeerOnline = seenDt == null ||
                DateTime.now().difference(seenDt).inMinutes <= 3;
          });
        }
      }

      final res = await client.rpc(
        'athlete_fetch_chat',
        params: {
          'p_athlete_id': widget.athlete.id,
          'p_access_code': widget.athlete.accessCode,
        },
      );

      if (res is List && mounted) {
        final prevIds = _messages.map((m) => m.id).toSet();
        for (final r in res) {
          if (r is! Map) continue;
          final msgId = r['id'] as String;
          final sender = r['sender_role'] as String;
          final text = r['message_text'] as String;
          final replyId = r['reply_to_id']?.toString();
          final readAtRaw = r['read_at']?.toString();

          final entity = ChatMessageEntity(
            id: msgId,
            athleteId: r['athlete_id'] as String,
            senderRole: sender,
            messageText: text,
            replyToId:
                (replyId != null && replyId.isNotEmpty) ? replyId : null,
            readAt: (readAtRaw != null && readAtRaw.isNotEmpty)
                ? DateTime.tryParse(readAtRaw)?.toLocal()
                : null,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            syncStatus: 'synced',
          );
          db.insertChatMessage(entity);

          // اگر پیام جدیدی از طرف مقابل آمده، نوتیفیکیشن زنده نشان بده
          if (!prevIds.contains(msgId) &&
              sender != widget.currentSenderRole &&
              prevIds.isNotEmpty) {
            ref.read(notificationCenterProvider.notifier).pushNotification(
                  eventKey: 'chat_$msgId',
                  title: sender == 'coach'
                      ? 'پیام جدید از مربی 💬'
                      : 'پیام جدید از ${widget.athlete.fullName} 💬',
                  body: text,
                  category: 'chat',
                  activeContext: context,
                );
          }
        }
        final updatedList = db.getChatMessagesForAthlete(widget.athlete.id);
        final shouldScroll = updatedList.length > _messages.length;
        setState(() => _messages = updatedList);
        if (shouldScroll) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  void _subscribeToRealtimeAndRpcChat() {
    _fetchChatAndPresenceViaRpc();
    _rpcChatPollTimer?.cancel();
    _rpcChatPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchChatAndPresenceViaRpc();
    });

    final client = SupabaseConfig.clientOrNull;
    if (client == null) return;
    final db = ref.read(appDatabaseProvider);

    _realtimeChatSub = client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('athlete_id', widget.athlete.id)
        .order('created_at', ascending: true)
        .listen((rows) {
      for (final r in rows) {
        final replyId = r['reply_to_id']?.toString();
        final readAtRaw = r['read_at']?.toString();
        db.insertChatMessage(ChatMessageEntity(
          id: r['id'] as String,
          athleteId: r['athlete_id'] as String,
          senderRole: r['sender_role'] as String,
          messageText: r['message_text'] as String,
          replyToId: (replyId != null && replyId.isNotEmpty) ? replyId : null,
          readAt: (readAtRaw != null && readAtRaw.isNotEmpty)
              ? DateTime.tryParse(readAtRaw)?.toLocal()
              : null,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          syncStatus: 'synced',
        ));
      }
      if (mounted) {
        setState(() {
          _messages = db.getChatMessagesForAthlete(widget.athlete.id);
        });
        _scrollToBottom();
      }
    }, onError: (_) {});
  }

  Future<void> _sendTextMessage([String? presetText]) async {
    final rawText = presetText ?? _msgCtrl.text;
    final text = rawText.toSanitizedText(maxLength: 500);
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    if (presetText == null) _msgCtrl.clear();

    final replyId = _replyingToMessage?.id;
    setState(() => _replyingToMessage = null);

    final msg = ChatMessageEntity(
      id: const Uuid().v4(),
      athleteId: widget.athlete.id,
      senderRole: widget.currentSenderRole,
      messageText: text,
      replyToId: replyId,
      createdAt: DateTime.now(),
    );

    final db = ref.read(appDatabaseProvider);
    db.insertChatMessage(msg);
    setState(() {
      _messages = db.getChatMessagesForAthlete(widget.athlete.id);
    });
    _scrollToBottom();

    try {
      final client = SupabaseConfig.clientOrNull;
      if (client != null) {
        if (widget.currentSenderRole == 'athlete') {
          final ok = await client.rpc(
            'athlete_send_chat',
            params: {
              'p_id': msg.id,
              'p_athlete_id': widget.athlete.id,
              'p_access_code': widget.athlete.accessCode,
              'p_message_text': msg.messageText,
              'p_reply_to_id': replyId,
            },
          );
          if (ok == true) {
            db.markRecordSynced('chat_messages', msg.id);
          }
        } else {
          final coachUid = client.auth.currentUser?.id;
          final payload = msg.toSupabaseJson();
          if (coachUid != null) {
            payload['coach_id'] = coachUid;
          }
          await client.from('chat_messages').upsert(payload);
          db.markRecordSynced('chat_messages', msg.id);
        }
      }
    } catch (_) {}
  }

  String _formatOnlineSubtitle(bool isFa) {
    if (_isPeerOnline) {
      return isFa ? '🟢 آنلاین در باشگاه' : '🟢 Online in Gym';
    }
    if (_peerLastSeenAt == null) {
      return isFa ? '🟢 ارتباط زنده برقرار است' : '🟢 Live Connected';
    }
    final diff = DateTime.now().difference(_peerLastSeenAt!);
    if (diff.inMinutes < 60) {
      return isFa
          ? 'آخرین بازدید ${diff.inMinutes} دقیقه پیش'
          : 'Last seen ${diff.inMinutes}m ago';
    }
    final hh = _peerLastSeenAt!.hour.toString().padLeft(2, '0');
    final mm = _peerLastSeenAt!.minute.toString().padLeft(2, '0');
    return isFa ? 'آخرین بازدید ساعت $hh:$mm' : 'Last seen at $hh:$mm';
  }

  Widget _buildPeerAvatar(Color primary, String peerTitle) {
    if (_peerAvatarB64.isNotEmpty) {
      try {
        final bytes = base64Decode(_peerAvatarB64);
        return CircleAvatar(
          radius: 21,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: 21,
      backgroundColor: primary.withOpacity(0.18),
      child: Text(
        peerTitle.isNotEmpty ? peerTitle.characters.first.toUpperCase() : 'M',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: primary,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final branding = ref.watch(brandingProvider);

    final peerTitle = widget.currentSenderRole == 'athlete'
        ? branding.coachName
        : widget.athlete.fullName;

    final msgById = <String, ChatMessageEntity>{
      for (final m in _messages) m.id: m,
    };

    final quickChips = widget.currentSenderRole == 'coach'
        ? _coachQuickRepliesFa
        : _athleteQuickRepliesFa;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // ۱. هدر تلگرامی با آواتار، نام و وضعیت آنلاین زنده
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111614),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: primary.withOpacity(0.28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _buildPeerAvatar(primary, peerTitle),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: _isPeerOnline
                                ? AppColors.success
                                : Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peerTitle,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatOnlineSubtitle(isFa),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                _isPeerOnline ? AppColors.success : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isFa ? 'بروزرسانی گفتگو' : 'Refresh Chat',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    onPressed: _fetchChatAndPresenceViaRpc,
                  ),
                ],
              ),
            ),

            // ۲. لیست حباب‌های پیام تلگرامی با ریپلای و تیک دوگانه (✓ / ✓✓)
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.messageSquareHeart,
                                size: 48, color: primary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              isFa
                                  ? 'گفتگوی اختصاصی تلگرامی آماده است.\nروی یکی از پیام‌های سریع پایین بزنید یا پیام خود را بنویسید...'
                                  : 'Direct Telegram-style chat ready. Send your first message...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[i];
                        final isMe = m.senderRole == widget.currentSenderRole;
                        final repliedMsg =
                            m.replyToId != null ? msgById[m.replyToId!] : null;
                        final timeStr =
                            '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';

                        return GestureDetector(
                          onHorizontalDragEnd: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _replyingToMessage = m);
                          },
                          onLongPress: () {
                            HapticFeedback.selectionClick();
                            setState(() => _replyingToMessage = m);
                          },
                          child: Align(
                            alignment: isMe
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              constraints: const BoxConstraints(maxWidth: 340),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? LinearGradient(
                                        colors: [
                                          primary.withOpacity(0.30),
                                          const Color(0xFF16241B),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isMe ? null : const Color(0xFF161C19),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 20),
                                ),
                                border: Border.all(
                                  color: isMe
                                      ? primary.withOpacity(0.55)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // کادر پیام ریپلای‌شده در بالای حباب (Telegram Reply Quote)
                                  if (repliedMsg != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.28),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border(
                                          right: BorderSide(
                                              color: primary, width: 3),
                                        ),
                                      ),
                                      child: Text(
                                        repliedMsg.messageText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    m.messageText,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          timeStr,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white54),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 5),
                                        Icon(
                                          m.isRead
                                              ? LucideIcons.checkCheck
                                              : LucideIcons.check,
                                          size: 14,
                                          color: m.isRead
                                              ? primary
                                              : Colors.white54,
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(
                                              () => _replyingToMessage = m);
                                        },
                                        child: const Icon(LucideIcons.reply,
                                            size: 12, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ۳. نوار چیپ‌های پیام آماده (Quick Action Chips)
            if (isFa)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: quickChips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF141916),
                      label: Text(
                        quickChips[idx],
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => _sendTextMessage(quickChips[idx]),
                    );
                  },
                ),
              ),

            // ۴. پیش‌نمایش پیام در حال ریپلای (در صورت انتخاب)
            if (_replyingToMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161D19),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border.all(color: primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.reply, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _replyingToMessage!.messageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.x, size: 15),
                      onPressed: () =>
                          setState(() => _replyingToMessage = null),
                    ),
                  ],
                ),
              ),

            // ۵. کادر تایپ و ارسال پیام
            Container(
              margin: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                widget.currentSenderRole == 'athlete' ? 94 : 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF121815),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLength: 500,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: isFa
                            ? 'پیام خود را بنویسید (نگه داشتن روی پیام = ریپلای)...'
                            : 'Type a live message (Long-press to reply)...',
                      ),
                      onSubmitted: (_) => _sendTextMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _sendTextMessage(),
                    icon: const Icon(LucideIcons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ۳. مودال ویرایش پروفایل، آپلود آواتار و تغییر رمز با Re-Authentication (بند 1.2 منشور)
// =============================================================================

class MaxGymProfileEditorModal extends ConsumerStatefulWidget {
  final bool isCoachMode;
  final AthleteEntity? athlete;
  final void Function(AthleteEntity updatedAthlete)? onAthleteUpdated;

  const MaxGymProfileEditorModal({
    super.key,
    required this.isCoachMode,
    this.athlete,
    this.onAthleteUpdated,
  });

  static Future<void> showForAthlete(
    BuildContext context, {
    required AthleteEntity athlete,
    required void Function(AthleteEntity updated) onUpdated,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => MaxGymProfileEditorModal(
        isCoachMode: false,
        athlete: athlete,
        onAthleteUpdated: onUpdated,
      ),
    );
  }

  static Future<void> showForCoach(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => const MaxGymProfileEditorModal(
        isCoachMode: true,
      ),
    );
  }

  @override
  ConsumerState<MaxGymProfileEditorModal> createState() =>
      _MaxGymProfileEditorModalState();
}

class _MaxGymProfileEditorModalState
    extends ConsumerState<MaxGymProfileEditorModal> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  String _avatarB64 = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCoachMode) {
      final branding = ref.read(brandingProvider);
      final parts = branding.coachName.split(' ');
      _firstNameCtrl.text = parts.isNotEmpty ? parts.first : '';
      _lastNameCtrl.text =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
      _bioCtrl.text = branding.coachCredentials;
      _loadCoachProfileFromCloud();
    } else if (widget.athlete != null) {
      final a = widget.athlete!;
      _firstNameCtrl.text = a.firstName;
      _lastNameCtrl.text = a.lastName;
      _phoneCtrl.text = a.phone;
      _weightCtrl.text = a.weightKg.toStringAsFixed(1);
      _loadAthleteAvatarFromCloud(a.id);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _weightCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCoachProfileFromCloud() async {
    try {
      final client = SupabaseConfig.clientOrNull;
      final uid = client?.auth.currentUser?.id;
      if (client == null || uid == null) return;
      final row = await client
          .from('coach_profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _firstNameCtrl.text =
              (row['first_name'] as String?) ?? _firstNameCtrl.text;
          _lastNameCtrl.text =
              (row['last_name'] as String?) ?? _lastNameCtrl.text;
          _phoneCtrl.text = (row['phone'] as String?) ?? '';
          _bioCtrl.text = (row['bio'] as String?) ?? _bioCtrl.text;
          _avatarB64 = (row['avatar_b64'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAthleteAvatarFromCloud(String athId) async {
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null) return;
      final row = await client
          .from('athletes')
          .select('bio, avatar_b64')
          .eq('id', athId)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _bioCtrl.text = (row['bio'] as String?) ?? '';
          _avatarB64 = (row['avatar_b64'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndCompressAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 220,
        maxHeight: 220,
        imageQuality: 70,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _avatarB64 = base64Encode(bytes);
        });
      }
    } catch (_) {}
  }

  bool _isStrongPassword(String pass) {
    if (pass.length < 10) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pass);
    final hasLower = RegExp(r'[a-z]').hasMatch(pass);
    final hasDigit = RegExp(r'[0-9]').hasMatch(pass);
    return hasUpper && hasLower && hasDigit;
  }

  Future<void> _saveProfileChanges(bool isFa) async {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final curPass = _currentPasswordCtrl.text.trim();
    final newPass = _newPasswordCtrl.text.trim();

    if (first.isEmpty) return;

    // بررسی سیاست امنیتی تغییر رمز عبور (بند 1.1 و 1.2 منشور Principal Security Architect)
    if (newPass.isNotEmpty) {
      if (curPass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFa
                ? '🔒 طبق پروتکل امنیتی، برای تغییر رمز عبور ابتدا باید رمز عبور فعلی خود را وارد کنید (Re-Authentication).'
                : '🔒 Current password is required to set a new password.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (!_isStrongPassword(newPass)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFa
                ? '🔒 رمز عبور جدید باید حداقل ۱۰ کاراکتر و شامل حروف بزرگ، کوچک انگلیسی و عدد باشد.'
                : '🔒 New password must be 10+ chars with uppercase, lowercase, and digits.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final client = SupabaseConfig.clientOrNull;

      if (widget.isCoachMode) {
        final fullName = '$first $last'.trim();
        final branding = ref.read(brandingProvider);
        await ref.read(brandingProvider.notifier).updateBranding(
              branding.copyWith(
                coachName: fullName,
                coachCredentials: _bioCtrl.text.trim(),
              ),
            );

        if (client != null && client.auth.currentUser != null) {
          final uid = client.auth.currentUser!.id;
          final email = client.auth.currentUser!.email ?? '';

          // اگر مربی قصد تغییر رمز عبور دارد، ابتدا Re-Authentication انجام شود
          if (newPass.isNotEmpty) {
            await client.auth.signInWithPassword(
              email: email,
              password: curPass,
            );
            await client.auth.updateUser(UserAttributes(password: newPass));
          }

          await client.from('coach_profiles').update({
            'first_name': first,
            'last_name': last,
            'phone': _phoneCtrl.text.toEnglishDigits(),
            'bio': _bioCtrl.text.trim(),
            'avatar_b64': _avatarB64,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', uid);
        }
      } else if (widget.athlete != null) {
        final a = widget.athlete!;
        final db = ref.read(appDatabaseProvider);

        // بررسی Re-Authentication محلی در صورت تغییر رمز ورزشکار
        if (newPass.isNotEmpty && a.passwordHash.isNotEmpty) {
          if (!AthleteEntity.verifyPasswordHash(curPass, a.passwordHash)) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isFa
                    ? '❌ رمز عبور فعلی اشتباه است! مجوز تغییر رمز صادر نشد.'
                    : '❌ Current password incorrect!'),
                backgroundColor: AppColors.danger,
              ),
            );
            return;
          }
        }

        final newWeight = _weightCtrl.text.toSafeDouble() ?? a.weightKg;
        final newHash = newPass.isNotEmpty
            ? AthleteEntity.hashPassword(newPass)
            : a.passwordHash;

        final updated = a.copyWith(
          firstName: first,
          lastName: last,
          phone: _phoneCtrl.text.toEnglishDigits(),
          weightKg: newWeight,
          passwordHash: newHash,
          isCodeBurned: true,
          updatedAt: DateTime.now(),
        );
        db.upsertAthlete(updated);

        if (newWeight != a.weightKg) {
          db.insertMeasurementLog(MeasurementLogEntity(
            id: const Uuid().v4(),
            athleteId: updated.id,
            recordedAt: DateTime.now(),
            weightKg: newWeight,
            updatedAt: DateTime.now(),
          ));
        }

        if (client != null) {
          await client.rpc('athlete_update_own_profile_secure', params: {
            'p_athlete_id': updated.id,
            'p_access_code': updated.accessCode,
            'p_current_password_hash':
                curPass.isNotEmpty ? AthleteEntity.hashPassword(curPass) : '',
            'p_first_name': updated.firstName,
            'p_last_name': updated.lastName,
            'p_phone': updated.phone,
            'p_bio': _bioCtrl.text.trim(),
            'p_avatar_b64': _avatarB64,
            'p_new_password_hash': newPass.isNotEmpty ? newHash : null,
          });
        }

        widget.onAthleteUpdated?.call(updated);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFa
                ? '✅ پروفایل و تنظیمات امنیتی با موفقیت بروزرسانی شد!'
                : '✅ Profile & security settings updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFa
                ? 'خطا در تایید هویت یا ذخیره تغییرات: $e'
                : 'Update failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final primary = Theme.of(context).colorScheme.primary;

    ImageProvider? avatarImg;
    if (_avatarB64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(_avatarB64));
      } catch (_) {}
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isCoachMode
                  ? (isFa
                      ? 'ویرایش پروفایل مربی و امنیت حساب'
                      : 'Edit Coach Profile & Security')
                  : (isFa
                      ? 'ویرایش پروفایل ورزشکار و امنیت حساب'
                      : 'Edit Athlete Profile & Security'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: _pickAndCompressAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: primary.withOpacity(0.18),
                      backgroundImage: avatarImg,
                      child: avatarImg == null
                          ? Icon(LucideIcons.user, size: 36, color: primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.camera,
                            size: 14, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameCtrl,
                    decoration: InputDecoration(
                      labelText: isFa ? 'نام *' : 'First Name *',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(
                      labelText: isFa ? 'نام خانوادگی' : 'Last Name',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isFa ? 'شماره موبایل' : 'Phone Number',
                        prefixIcon: const Icon(LucideIcons.phone, size: 18),
                      ),
                    ),
                  ),
                ),
                if (!widget.isCoachMode) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isFa ? 'وزن (kg)' : 'Weight',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              decoration: InputDecoration(
                labelText: widget.isCoachMode
                    ? (isFa
                        ? 'مدارک و بیوگرافی مربی'
                        : 'Coach Bio & Credentials')
                    : (isFa
                        ? 'شعار یا هدف ورزشی من در باشگاه'
                        : 'My Fitness Bio / Motto'),
                prefixIcon: const Icon(LucideIcons.sparkles, size: 18),
              ),
            ),
            const Divider(height: 28, color: Colors.white12),
            Text(
              isFa
                  ? '🔐 تغییر رمز عبور با تایید مجدد (Re-Authentication):'
                  : '🔐 Change Password (Re-Authentication Required):',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _currentPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'رمز عبور فعلی (الزامی در صورت تغییر رمز)'
                      : 'Current Password',
                  prefixIcon: const Icon(LucideIcons.lock, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _newPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'رمز عبور جدید (حداقل ۱۰ کاراکتر با حروف بزرگ/کوچک و عدد)'
                      : 'New Strong Password (min 10 chars)',
                  prefixIcon: const Icon(LucideIcons.keyRound, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveProfileChanges(isFa),
              icon: const Icon(LucideIcons.checkCircle2),
              label: Text(isFa
                  ? 'ذخیره پروفایل و تنظیمات امنیتی'
                  : 'Save Profile & Security'),
            ),
          ],
        ),
      ),
    );
  }
}
