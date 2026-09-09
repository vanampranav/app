import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ask_ele_proposal.dart';
import '../../models/ask_ele_recommendation.dart';
import '../../models/food_models.dart';
import '../../services/ask_ele_context_service.dart';
import '../../services/backend_service.dart';
import '../../services/speech_input_service.dart';
import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ask_ele/ask_ele_input_bar.dart';
import '../../widgets/ask_ele/ask_ele_meal_proposal_card.dart';
import '../../widgets/ask_ele/ask_ele_meal_recommendation_card.dart';
import '../../widgets/ask_ele/ask_ele_message_bubble.dart';
import '../../widgets/ask_ele/ask_ele_quick_action_chip.dart';
import '../../widgets/ask_ele/ask_ele_summary_metric.dart';

enum ChatMessageType { text, mealProposal, mealRecommendation }
enum AskEleIntent { logMeal, dailyGuidance }

class ChatMessage {
  final String? text;
  final MealProposal? proposal;
  final MealRecommendationResponse? recommendation;
  final bool isUser;
  final ChatMessageType type;

  ChatMessage.text({
    required String this.text,
    required this.isUser,
  })  : proposal = null,
        recommendation = null,
        type = ChatMessageType.text;

  ChatMessage.proposal({
    required MealProposal this.proposal,
  })  : text = null,
        recommendation = null,
        isUser = false,
        type = ChatMessageType.mealProposal;

  ChatMessage.recommendation({
    required MealRecommendationResponse this.recommendation,
  })  : text = null,
        proposal = null,
        isUser = false,
        type = ChatMessageType.mealRecommendation;
}

class PendingMealClarification {
  final int itemIndex;
  final String interpretedName;
  final String status;
  final String question;

  PendingMealClarification({
    required this.itemIndex,
    required this.interpretedName,
    required this.status,
    required this.question,
  });
}

class RecommendationContext {
  final String mealType;
  final List<String> suggestedFoods;
  final String? recommendationId;
  final String? selectedOptionId;
  final List<MealRecommendationOption>? options;

  RecommendationContext({
    required this.mealType,
    required this.suggestedFoods,
    this.recommendationId,
    this.selectedOptionId,
    this.options,
  });

  Map<String, dynamic> toJson() => {
        'mealType': mealType,
        'suggestedFoods': suggestedFoods,
        if (recommendationId != null) 'recommendationId': recommendationId,
        if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
        if (options != null)
          'options': options!.map((o) => o.toJson()).toList(),
      };

  factory RecommendationContext.fromJson(Map<String, dynamic> json) {
    final rawList = json['suggestedFoods'] as List<dynamic>? ?? [];
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return RecommendationContext(
      mealType: json['mealType'] as String? ?? 'snack',
      suggestedFoods: rawList.map((e) => e.toString()).toList(),
      recommendationId: json['recommendationId'] as String?,
      selectedOptionId: json['selectedOptionId'] as String?,
      options: rawOptions.isNotEmpty
          ? rawOptions
              .map((e) => MealRecommendationOption.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList()
          : null,
    );
  }
}

class AskEleScreen extends StatefulWidget {
  final String? initialQuery;
  final int? caloriesConsumed;
  final int? caloriesGoal;
  final int? proteinGrams;
  final int? proteinGoal;
  final int? stepsCount;

  const AskEleScreen({
    super.key,
    this.initialQuery,
    this.caloriesConsumed,
    this.caloriesGoal,
    this.proteinGrams,
    this.proteinGoal,
    this.stepsCount,
  });

  @override
  State<AskEleScreen> createState() => _AskEleScreenState();
}

class _AskEleScreenState extends State<AskEleScreen> {
  final BackendService _backendService = BackendService();
  final SpeechInputService _speechService = SpeechInputService();
  final AskEleContextService _contextService = AskEleContextService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isLoggingMeal = false;
  bool _isListening = false;
  String _baseTextBeforeSpeech = '';

  int? _caloriesConsumed;
  int? _proteinGrams;

  late final String _sessionId;
  Map<String, dynamic>? _activeMealProposal;
  PendingMealClarification? _pendingClarification;
  RecommendationContext? _activeRecommendationContext;
  final Set<String> _loggedOriginalTexts = {};

  final List<String> _quickPrompts = [
    'I had 2 idlis with chutney',
    'Log a meal',
    'Build my workout',
    'Why is my weight stuck?',
    'Adjust my calories',
    'My progress',
  ];

  @override
  void initState() {
    super.initState();
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _caloriesConsumed = widget.caloriesConsumed;
    _proteinGrams = widget.proteinGrams;

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _speechService.stopListening();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _caloriesSummary {
    if (_caloriesConsumed != null &&
        widget.caloriesGoal != null &&
        widget.caloriesGoal! > 0) {
      return '$_caloriesConsumed / ${widget.caloriesGoal}';
    }
    if (_caloriesConsumed != null) {
      return '$_caloriesConsumed kcal';
    }
    return '—';
  }

  String get _proteinSummary {
    if (_proteinGrams != null &&
        widget.proteinGoal != null &&
        widget.proteinGoal! > 0) {
      return '$_proteinGrams / ${widget.proteinGoal}g';
    }
    if (_proteinGrams != null) {
      return '$_proteinGrams g';
    }
    return '—';
  }

  String get _stepsSummary {
    if (widget.stepsCount != null && widget.stepsCount! > 0) {
      final s = widget.stepsCount!;
      if (s >= 10000) {
        final thousands = (s / 1000).toStringAsFixed(1);
        return '${thousands}k';
      }
      return '$s';
    }
    return '—';
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

  int _speechSessionId = 0;

  Future<void> _handleMicTap() async {
    if (_isListening) {
      _speechSessionId++;
      await _speechService.cancelListening();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    _baseTextBeforeSpeech = _inputController.text;
    final currentSession = ++_speechSessionId;

    setState(() {
      _isListening = true;
    });

    await _speechService.startListening(
      onResult: (transcript, isFinal) {
        if (!mounted || currentSession != _speechSessionId) return;
        final prefix = _baseTextBeforeSpeech.trim();
        final combined = prefix.isEmpty ? transcript : '$prefix $transcript';
        _inputController.text = combined;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
        if (isFinal) {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorMsg) {
        if (!mounted || currentSession != _speechSessionId) return;
        setState(() {
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      },
      onStatusChanged: () {
        if (mounted && currentSession == _speechSessionId) {
          setState(() {
            _isListening = _speechService.isListening;
          });
        }
      },
    );
  }

  bool _isConversationalLogCommand(String query) {
    final norm = query.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
    const logCommands = {
      'log it',
      'yes log it',
      'go ahead',
      'add it',
      'log this',
      'confirm',
      'yes log',
      'please log it',
      'log',
      'save it',
      'save meal',
      'log meal',
      'yes',
    };
    return logCommands.contains(norm);
  }

  AskEleIntent _classifyIntent(String query) {
    final norm = query.toLowerCase().trim();

    final questionMatch = RegExp(
      r'\b(how am i doing|how is my day|hows my day|am i on track|how many|how much|what should i|what can i|recommend|recommendation|remaining|left|calories left|protein left|carbs left|fat left|today summary|my progress|should i eat|can i eat)\b',
    );

    if (questionMatch.hasMatch(norm) || norm.contains('?')) {
      if (norm.startsWith('i had ') ||
          norm.startsWith('i ate ') ||
          norm.startsWith('log ') ||
          norm.startsWith('add ')) {
        if (!norm.contains('left') &&
            !norm.contains('remaining') &&
            !norm.contains('doing') &&
            !norm.contains('on track') &&
            !norm.contains('should i eat')) {
          return AskEleIntent.logMeal;
        }
      }
      return AskEleIntent.dailyGuidance;
    }

    final logMatch = RegExp(r'\b(i had|i ate|i drank|log|add|ate|had)\b');
    if (logMatch.hasMatch(norm)) {
      return AskEleIntent.logMeal;
    }

    return AskEleIntent.logMeal;
  }

  void _updateActiveProposalAndPendingClarification(
      Map<String, dynamic> proposalMap) {
    _activeMealProposal = proposalMap;
    final proposal = MealProposal.fromJson(proposalMap);

    _pendingClarification = null;

    if (proposal.needsClarification && proposal.items.isNotEmpty) {
      for (int i = 0; i < proposal.items.length; i++) {
        final item = proposal.items[i];
        if (!item.isResolved) {
          final question = proposal.clarificationQuestion ??
              item.clarificationQuestion ??
              'How much ${item.interpretedName} did you have?';
          _pendingClarification = PendingMealClarification(
            itemIndex: i,
            interpretedName: item.interpretedName,
            status: item.status,
            question: question,
          );
          break;
        }
      }
    }
  }

  String? _parseMealTypeUpdate(String text) {
    final norm = text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

    if (norm.contains('?') ||
        norm.startsWith('what ') ||
        norm.startsWith('how ') ||
        norm.startsWith('why ') ||
        norm.startsWith('is ') ||
        norm.startsWith('can ') ||
        norm.startsWith('should ') ||
        norm.contains('recommend')) {
      return null;
    }

    if (norm == 'breakfast') return 'breakfast';
    if (norm == 'lunch') return 'lunch';
    if (norm == 'dinner') return 'dinner';
    if (norm == 'snack' || norm == 'snacks' || norm == 'a snack') {
      return 'snacks';
    }

    final explicitEditMatch = RegExp(
      r'^(this is for|this is|make (this|it)|this was|actually|change (it|this) to|change to|for|as)\s+(breakfast|lunch|dinner|snack|snacks)$',
    );

    final match = explicitEditMatch.firstMatch(norm);
    if (match != null) {
      final mealStr = match.group(3) ?? match.group(2) ?? match.group(1);
      if (mealStr != null) {
        if (mealStr.contains('breakfast')) return 'breakfast';
        if (mealStr.contains('lunch')) return 'lunch';
        if (mealStr.contains('dinner')) return 'dinner';
        if (mealStr.contains('snack')) return 'snacks';
      }
    }

    return null;
  }

  MealType _parseMealTypeEnum(String? typeStr) {
    if (typeStr == null) return MealType.snacks;
    final norm = typeStr.toLowerCase().trim();
    if (norm == 'breakfast') return MealType.breakfast;
    if (norm == 'lunch') return MealType.lunch;
    if (norm == 'dinner') return MealType.dinner;
    return MealType.snacks;
  }

  String _formatMealTypeName(String? typeStr) {
    if (typeStr == null || typeStr.isEmpty) return 'Meal';
    final norm = typeStr.toLowerCase().trim();
    if (norm == 'breakfast') return 'Breakfast';
    if (norm == 'lunch') return 'Lunch';
    if (norm == 'dinner') return 'Dinner';
    return 'Snack';
  }

  Future<void> _handleConfirmAndLog(MealProposal proposal) async {
    if (_isLoggingMeal || !proposal.readyToLog) return;

    setState(() {
      _isLoggingMeal = true;
    });

    try {
      final now = DateTime.now();
      final mealTypeEnum = _parseMealTypeEnum(proposal.mealType);

      final List<MealEntry> entriesToSave = [];
      for (int i = 0; i < proposal.items.length; i++) {
        final item = proposal.items[i];
        if (!item.isResolved || item.nutrition == null) {
          throw Exception('Item "${item.interpretedName}" is not resolved.');
        }

        final entryId = 'ask_ele_${now.millisecondsSinceEpoch}_$i';
        final foodName = item.matchedFoodName ?? item.interpretedName;
        final fdcId = item.matchedFoodId ?? 'ask_ele';
        final weight = item.weightGrams ?? 100.0;

        final entry = MealEntry(
          id: entryId,
          foodName: foodName,
          fdcId: fdcId,
          weight: weight,
          nutrition: item.nutrition!,
          meal: mealTypeEnum,
          timestamp: now,
        );

        entriesToSave.add(entry);
      }

      // Save each item to backend Firestore via saveMeal
      final List<MealEntry> savedEntries = [];
      for (final entry in entriesToSave) {
        await _backendService.saveMeal(
          entry,
          source: 'ask_ele',
          nutritionSource: 'fatsecret',
        );
        savedEntries.add(entry);
      }

      // Sync to local SharedPreferences for Nutrition screen & Home
      final prefs = await SharedPreferences.getInstance();
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final existingJson = prefs.getString('meal_entries_$dateKey');
      final List<dynamic> existingList =
          existingJson != null ? jsonDecode(existingJson) : [];
      existingList.addAll(savedEntries.map((e) => e.toJson()));
      await prefs.setString('meal_entries_$dateKey', jsonEncode(existingList));

      // Update Home & Today's Summary keys
      final homeKey = '${now.year}_${now.month}_${now.day}';
      final totalCal = proposal.resolvedNutritionTotal?.calories ?? 0.0;
      final totalProt = proposal.resolvedNutritionTotal?.protein ?? 0.0;
      final totalCarbs = proposal.resolvedNutritionTotal?.carbs ?? 0.0;
      final totalFat = proposal.resolvedNutritionTotal?.fat ?? 0.0;

      final currentCal = prefs.getInt('cal_consumed_$homeKey') ?? 0;
      final currentProt = prefs.getInt('protein_$homeKey') ?? 0;
      final currentCarbs = prefs.getInt('carbs_$homeKey') ?? 0;
      final currentFat = prefs.getInt('fat_$homeKey') ?? 0;

      final newCal = currentCal + totalCal.round();
      final newProt = currentProt + totalProt.round();
      final newCarbs = currentCarbs + totalCarbs.round();
      final newFat = currentFat + totalFat.round();

      await prefs.setInt('cal_consumed_$homeKey', newCal);
      await prefs.setInt('protein_$homeKey', newProt);
      await prefs.setInt('carbs_$homeKey', newCarbs);
      await prefs.setInt('fat_$homeKey', newFat);

      await StreakService.recordActivity();

      if (!mounted) return;

      _loggedOriginalTexts.add(proposal.originalText);

      setState(() {
        _caloriesConsumed = newCal;
        _proteinGrams = newProt;

        // Clear active meal and recommendation state
        _activeMealProposal = null;
        _pendingClarification = null;
        _activeRecommendationContext = null;

        final mealTypeName = _formatMealTypeName(proposal.mealType);
        _messages.add(
          ChatMessage.text(
            text: 'Meal logged ✓',
            isUser: false,
          ),
        );
        _messages.add(
          ChatMessage.text(
            text:
                '$mealTypeName added — ${totalCal.round()} kcal and ${totalProt.round()}g protein.',
            isUser: false,
          ),
        );
      });
    } catch (e) {
      debugPrint('Error logging meal in AskEleScreen: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage.text(
            text:
                "I couldn't finish logging that meal. Your meal is still here — please try again.",
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingMeal = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _handleOptionSelection(
    MealRecommendationResponse rec,
    MealRecommendationOption option,
  ) {
    try {
      _backendService.saveRecommendationFeedback(
        action: 'selected',
        recommendationId: rec.recommendationId,
        optionId: option.optionId,
      ).catchError((e) {
        debugPrint('Feedback save error (ignored): $e');
        return <String, dynamic>{};
      });
    } catch (e) {
      debugPrint('Failed to send selection feedback: $e');
    }

    _activeRecommendationContext = RecommendationContext(
      mealType: rec.mealType,
      suggestedFoods: option.foods,
      recommendationId: rec.recommendationId,
      selectedOptionId: option.optionId,
      options: rec.options,
    );

    _handleSendMessage("I'll choose ${option.title}");
  }

  void _handleRecommendationRefresh(MealRecommendationResponse rec) {
    try {
      _backendService.saveRecommendationFeedback(
        action: 'refreshed',
        recommendationId: rec.recommendationId,
      ).catchError((e) {
        debugPrint('Feedback save error (ignored): $e');
        return <String, dynamic>{};
      });
    } catch (e) {
      debugPrint('Failed to send refresh feedback: $e');
    }

    _handleSendMessage('Give me a different ${rec.mealType} recommendation');
  }

  void _handleOptionFeedback(
    String recommendationId,
    String optionId,
    String action,
  ) {
    try {
      _backendService.saveRecommendationFeedback(
        action: action,
        recommendationId: recommendationId,
        optionId: optionId,
      ).catchError((e) {
        debugPrint('Feedback save error (ignored): $e');
        return <String, dynamic>{};
      });
    } catch (e) {
      debugPrint('Failed to send option feedback: $e');
    }
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final query = (overrideText ?? _inputController.text).trim();

    FocusScope.of(context).unfocus();

    _speechSessionId++;
    _baseTextBeforeSpeech = '';

    if (_isListening || _speechService.isListening) {
      _speechService.cancelListening();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }

    _inputController.clear();

    if (query.isEmpty || _isLoading || _isLoggingMeal) return;

    setState(() {
      _messages.add(ChatMessage.text(text: query, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final isLogCmd = _isConversationalLogCommand(query);

      // 1. CONVERSATIONAL "LOG IT" COMMAND ON READY PROPOSAL
      if (isLogCmd && _activeMealProposal != null) {
        final proposal = MealProposal.fromJson(_activeMealProposal!);
        if (proposal.readyToLog) {
          await _handleConfirmAndLog(proposal);
          return;
        }
      }

      // 2. UNIFIED BACKEND CONVERSATION SESSION TURN PROCESSING
      final todayContext = await _contextService.getTodayContext();
      final turnResult = await _backendService.processConversationTurn(
        sessionId: _sessionId,
        message: query,
        todayContext: todayContext.toJson(),
        recommendationContext: _activeRecommendationContext?.toJson(),
      );

      if (!mounted) return;

      final responseText = turnResult['responseText'] as String? ?? '';

      // Render updated MealProposal
      if (turnResult['proposal'] is Map<String, dynamic>) {
        final proposalMap =
            Map<String, dynamic>.from(turnResult['proposal'] as Map);
        _updateActiveProposalAndPendingClarification(proposalMap);
        final proposal = MealProposal.fromJson(proposalMap);

        setState(() {
          if (responseText.isNotEmpty &&
              responseText != proposal.clarificationQuestion &&
              !responseText.startsWith('Could you clarify') &&
              !responseText.startsWith('Updated meal')) {
            _messages.add(ChatMessage.text(text: responseText, isUser: false));
          }
          _messages.add(ChatMessage.proposal(proposal: proposal));

          if (proposal.needsClarification &&
              proposal.clarificationQuestion != null &&
              proposal.clarificationQuestion!.isNotEmpty) {
            final nextQ = proposal.clarificationQuestion!;
            final lastText =
                _messages.isNotEmpty ? _messages.last.text : null;
            if (lastText != nextQ) {
              _messages.add(ChatMessage.text(text: nextQ, isUser: false));
            }
          }
        });
        return;
      }

      // Render updated MealRecommendation
      if (turnResult['recommendation'] is Map<String, dynamic>) {
        final recMap =
            Map<String, dynamic>.from(turnResult['recommendation'] as Map);
        _activeRecommendationContext =
            RecommendationContext.fromJson(recMap);
        if (recMap['options'] is List &&
            (recMap['options'] as List).isNotEmpty) {
          final structuredRec = MealRecommendationResponse.fromJson(recMap);
          setState(() {
            if (responseText.isNotEmpty) {
              _messages.add(
                  ChatMessage.text(text: responseText, isUser: false));
            }
            _messages.add(
              ChatMessage.recommendation(recommendation: structuredRec),
            );
          });
          return;
        }
      }

      // General guidance / response
      setState(() {
        if (responseText.isNotEmpty) {
          _messages.add(ChatMessage.text(text: responseText, isUser: false));
        }
      });
    } catch (e) {

      // 4. RECOMMENDATION FOLLOW-UP / GUIDANCE / RECOMMENDATION REQUEST
      if (_activeRecommendationContext != null ||
          intent == AskEleIntent.dailyGuidance) {
        final todayContext = await _contextService.getTodayContext();
        final guidanceData = await _backendService.getAskEleGuidance(
          message: query,
          todayContext: todayContext.toJson(),
          recommendationContext: _activeRecommendationContext?.toJson(),
        );

        if (!mounted) return;

        final responseText =
            guidanceData['responseText'] as String? ?? '';

        // Update recommendation context if returned
        MealRecommendationResponse? structuredRec;
        if (guidanceData['recommendation'] is Map<String, dynamic>) {
          final recMap = Map<String, dynamic>.from(
              guidanceData['recommendation'] as Map);
          _activeRecommendationContext =
              RecommendationContext.fromJson(recMap);
          if (recMap['options'] is List &&
              (recMap['options'] as List).isNotEmpty) {
            structuredRec = MealRecommendationResponse.fromJson(recMap);
          }
        }

        // If backend returned a prepared proposal (because quantities were provided for recommendation)
        if (guidanceData['proposal'] is Map<String, dynamic>) {
          final proposalMap = Map<String, dynamic>.from(
              guidanceData['proposal'] as Map);
          _updateActiveProposalAndPendingClarification(proposalMap);
          final proposal = MealProposal.fromJson(proposalMap);

          setState(() {
            if (responseText.isNotEmpty) {
              _messages
                  .add(ChatMessage.text(text: responseText, isUser: false));
            }
            _messages.add(
              ChatMessage.text(
                text: "Got it — here's what I understood.",
                isUser: false,
              ),
            );
            _messages.add(ChatMessage.proposal(proposal: proposal));

            if (proposal.needsClarification &&
                proposal.clarificationQuestion != null &&
                proposal.clarificationQuestion!.isNotEmpty) {
              _messages.add(
                ChatMessage.text(
                  text: proposal.clarificationQuestion!,
                  isUser: false,
                ),
              );
            }
          });
          return;
        }

        // If backend returned preparedMealText (fallback if proposal not pre-computed)
        final preparedMealText =
            guidanceData['preparedMealText'] as String?;
        final suggestedMealType =
            guidanceData['suggestedMealType'] as String?;
        if (preparedMealText != null && preparedMealText.isNotEmpty) {
          final proposalMap = await _backendService.prepareMeal(
            preparedMealText,
            suggestedMealType: suggestedMealType ??
                _activeRecommendationContext?.mealType,
          );
          final proposal = MealProposal.fromJson(proposalMap);

          if (!mounted) return;

          _updateActiveProposalAndPendingClarification(proposalMap);

          setState(() {
            if (responseText.isNotEmpty) {
              _messages
                  .add(ChatMessage.text(text: responseText, isUser: false));
            }
            _messages.add(
              ChatMessage.text(
                text: "Got it — here's what I understood.",
                isUser: false,
              ),
            );
            _messages.add(ChatMessage.proposal(proposal: proposal));

            if (proposal.needsClarification &&
                proposal.clarificationQuestion != null &&
                proposal.clarificationQuestion!.isNotEmpty) {
              _messages.add(
                ChatMessage.text(
                  text: proposal.clarificationQuestion!,
                  isUser: false,
                ),
              );
            }
          });
          return;
        }

        // Standard guidance or structured recommendation cards
        setState(() {
          if (responseText.isNotEmpty) {
            _messages
                .add(ChatMessage.text(text: responseText, isUser: false));
          }
          if (structuredRec != null) {
            _messages.add(
              ChatMessage.recommendation(recommendation: structuredRec),
            );
          }
        });
        return;
      }

      // 5. NEW MEAL LOG ACTION
      final proposalMap = await _backendService.prepareMeal(query);
      final proposal = MealProposal.fromJson(proposalMap);

      if (!mounted) return;

      _updateActiveProposalAndPendingClarification(proposalMap);

      // Clear active recommendation if starting a completely independent new meal log
      _activeRecommendationContext = null;

      setState(() {
        if (proposal.items.isNotEmpty) {
          _messages.add(
            ChatMessage.text(
              text: 'Got it — here\'s what I understood.',
              isUser: false,
            ),
          );
          _messages.add(ChatMessage.proposal(proposal: proposal));

          if (proposal.needsClarification &&
              proposal.clarificationQuestion != null &&
              proposal.clarificationQuestion!.isNotEmpty) {
            final question = proposal.clarificationQuestion!;
            final lastMsg =
                _messages.isNotEmpty ? _messages.last.text : null;
            if (lastMsg != question) {
              _messages.add(
                ChatMessage.text(
                  text: question,
                  isUser: false,
                ),
              );
            }
          }
        } else {
          final question = proposal.clarificationQuestion ??
              'I couldn\'t identify any foods in that meal. Try describing what you ate, e.g. "2 idlis with chutney".';
          _messages.add(ChatMessage.text(text: question, isUser: false));
        }
      });
    } catch (e) {
      debugPrint('Error in AskEleScreen message routing: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage.text(
            text: 'I couldn\'t work that out right now. Try again in a moment.',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Ask Ele', style: AppTheme.headingSM),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.purple,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'BETA',
                    style: AppTheme.labelSM.copyWith(
                      fontSize: 9,
                      color: AppTheme.lime,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Your AI Fitness Assistant',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded,
                color: AppTheme.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat history - Coming Soon'),
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // ── Today's Summary Section ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.md,
                vertical: AppTheme.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY\'S SUMMARY',
                    style: AppTheme.labelSM.copyWith(
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Row(
                    children: [
                      AskEleSummaryMetric(
                        label: 'Calories',
                        value: _caloriesSummary,
                        icon: Icons.local_fire_department_rounded,
                      ),
                      const SizedBox(width: AppTheme.xs),
                      AskEleSummaryMetric(
                        label: 'Protein',
                        value: _proteinSummary,
                        icon: Icons.fitness_center_rounded,
                      ),
                      const SizedBox(width: AppTheme.xs),
                      AskEleSummaryMetric(
                        label: 'Steps',
                        value: _stepsSummary,
                        icon: Icons.directions_walk_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider, height: 1),

            // ── Conversation Content ───────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppTheme.md),
                children: [
                // Ele Initial Welcome Card
                Container(
                  padding: const EdgeInsets.all(AppTheme.md),
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.purple.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.lime.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.lime,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi! I\'m Ele, your AI fitness assistant.',
                              style: AppTheme.headingSM.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: AppTheme.xs),
                            Text(
                              'You can ask me anything about nutrition, workouts, progress, or your goals.',
                              style: AppTheme.bodyMD.copyWith(
                                color: AppTheme.textPrimary.withValues(alpha: 0.9),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.lg),

                // Quick Prompts Section
                if (_messages.isEmpty) ...[
                  Text(
                    'Try something like:',
                    style: AppTheme.labelMD.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Wrap(
                    spacing: AppTheme.xs,
                    runSpacing: AppTheme.xs,
                    children: _quickPrompts.map((prompt) {
                      return AskEleQuickActionChip(
                        label: prompt,
                        icon: Icons.chat_bubble_outline_rounded,
                        onTap: () {
                          _inputController.text = prompt;
                          _handleSendMessage();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.lg),
                ],

                // Conversation Message List
                ..._messages.map((msg) {
                  if (msg.type == ChatMessageType.mealProposal &&
                      msg.proposal != null) {
                    final isLogged = _loggedOriginalTexts.contains(
                        msg.proposal!.originalText);
                    return AskEleMealProposalCard(
                      proposal: msg.proposal!,
                      onConfirmAndLog: () => _handleConfirmAndLog(msg.proposal!),
                      isLogging: _isLoggingMeal,
                      isLogged: isLogged,
                    );
                  }
                  if (msg.type == ChatMessageType.mealRecommendation &&
                      msg.recommendation != null) {
                    return AskEleMealRecommendationCard(
                      recommendation: msg.recommendation!,
                      selectedOptionId:
                          _activeRecommendationContext?.selectedOptionId,
                      onOptionSelected: (option) => _handleOptionSelection(
                          msg.recommendation!, option),
                      onFeedback: (optionId, action) => _handleOptionFeedback(
                          msg.recommendation!.recommendationId,
                          optionId,
                          action),
                      onRefresh: () =>
                          _handleRecommendationRefresh(msg.recommendation!),
                    );
                  }
                  return AskEleMessageBubble(
                    text: msg.text ?? '',
                    isUser: msg.isUser,
                  );
                }),

                // Ele Loading State
                if (_isLoading) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.purple,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.lime.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.lime,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ele is working it out...',
                          style: AppTheme.bodySM.copyWith(
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.lime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom Persistent Input Bar ────────────────────────────────────
          AskEleInputBar(
            controller: _inputController,
            onSend: _handleSendMessage,
            onMicTap: _handleMicTap,
            isLoading: _isLoading || _isLoggingMeal,
            isListening: _isListening,
          ),
        ],
      ),
    ),
  );
}
}
