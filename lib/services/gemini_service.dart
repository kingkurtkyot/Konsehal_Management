import 'dart:convert';
import 'dart:io' show InternetAddress, SocketException;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/schedule_event.dart';
import '../models/solicitation.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'storage_service.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';


  /// Extracts schedule events from an image
  static Future<List<ScheduleEvent>> extractScheduleFromImage(XFile imageFile) async {
    const prompt = '''
You are an expert at extracting structured schedule/event data from images.

Analyze this image and extract ALL schedule events. For each event, extract:
- date (format: MM/DD/YYYY or as shown)
- time (format: HH:MM AM/PM)
- dayOfWeek (Monday, Tuesday, etc.)
- theme (the event name/title/description)
- location (venue, address, or place if mentioned; otherwise "Not specified")
- fullDescription (complete description combining all details)
- id (generate a unique string like "evt_1", "evt_2", etc.)

Respond ONLY with a valid JSON array. If no events are found, return an empty array: []
''';

    final response = await _callAPI(prompt, imageFile);
    return _parseScheduleResponse(response);
  }

  /// Extracts schedule events from raw text using AI
  static Future<List<ScheduleEvent>> extractScheduleFromText(String rawText) async {
    final prompt = '''
You are an expert at extracting structured schedule/event data from text.

Analyze this text and extract ALL schedule events. For each event, extract:
- date (format: MM/DD/YYYY - convert any date format to this)
- time (format: HH:MM AM/PM)
- dayOfWeek (Monday, Tuesday, etc. - calculate this from the date)
- theme (the event name/title/description)
- location (venue, address, or place if mentioned; otherwise "Not specified")
- fullDescription (a formal, professional description combining all details in a complete sentence)
- id (generate a unique string like "evt_1", "evt_2", etc.)

Make the fullDescription formal and professional - suitable for official reports.

TEXT TO PROCESS:
$rawText

Respond ONLY with a valid JSON array. If no events are found, return an empty array: []
''';

    final response = await _callTextAPI(prompt);
    return _parseScheduleResponse(response);
  }

  /// Extracts solicitations from an image
  static Future<List<Solicitation>> extractSolicitationsFromImage(XFile imageFile) async {
    const prompt = '''
You are an expert at extracting structured solicitation/request data from images.

Analyze this image and extract ALL solicitation entries. For each solicitation, extract:
- id: unique string like "sol_1", "sol_2"
- organizationOrPerson: name of the organization or person requesting
- purpose: what they are requesting / what the money is for
- targetDate: deadline or target date (e.g. "ASAP", "April 2026", "March 28-29, 2026")
- contactPerson: name of the contact person (or empty string if not mentioned)
- contactNumber: phone number(s) (or empty string if not mentioned)
- status: "pending" if it is still pending/waiting, "completed" if marked as OK/done/completed
- amountGiven: amount given if status is completed (e.g. "₱500", "₱100"), or null if not applicable
- additionalNotes: any other relevant notes, gcash info, etc.

Respond ONLY with a valid JSON array. If no solicitations are found, return: []
''';

    final response = await _callAPI(prompt, imageFile);
    return _parseSolicitationResponse(response);
  }

  /// Extracts solicitations from raw text using AI
  static Future<List<Solicitation>> extractSolicitationsFromText(String rawText) async {
    final prompt = '''
You are an expert at extracting structured solicitation/request data from text.

Analyze this text and extract ALL solicitation entries. For each solicitation, extract:
- id: unique string like "sol_1", "sol_2"
- organizationOrPerson: name of the organization or person requesting
- purpose: a formal, professional description of what they are requesting
- targetDate: deadline or target date in MM/DD/YYYY format if possible
- contactPerson: name of the contact person (or empty string if not mentioned)
- contactNumber: phone number(s) (or empty string if not mentioned)
- status: "pending"
- amountGiven: null
- additionalNotes: any other relevant notes, make it formal and professional

Make all descriptions formal and professional - suitable for official reports.

TEXT TO PROCESS:
$rawText

Respond ONLY with a valid JSON array. If no solicitations are found, return: []
''';

    final response = await _callTextAPI(prompt);
    return _parseSolicitationResponse(response);
  }

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true; // Most web browsers already handle basic connectivity or fail gracefully
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return true; // Fallback for other platforms
    }
  }

  static GenerativeModel _createModel() {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Call API with image
  static Future<String> _callAPI(String prompt, XFile imageFile) async {
    try {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection. Please enable WiFi or mobile data.');
      }

      final model = _createModel();
      final imageBytes = await imageFile.readAsBytes();
      final mimeType = _getMimeType(imageFile.path);

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ])
      ];

      final response = await _generateWithRetry(model, content);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('AI returned an empty response.');
      }

      return response.text!;
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Call API with text only (no image)
  static Future<String> _callTextAPI(String prompt) async {
    try {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection. Please enable WiFi or mobile data.');
      }

      final model = _createModel();

      final content = [
        Content.text(prompt),
      ];

      final response = await _generateWithRetry(model, content);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('AI returned an empty response.');
      }

      return response.text!;
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Helper to retry request automatically if rate limit (429) is hit
  static Future<GenerateContentResponse> _generateWithRetry(GenerativeModel model, List<Content> content) async {
    int maxRetries = 2; // Try up to 2 times
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await model.generateContent(content);
      } catch (e) {
        if (i == maxRetries - 1) rethrow; // Let it bubble up on last failure
        
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('429') || 
            errorString.contains('too many requests') || 
            errorString.contains('quota') ||
            errorString.contains('exhausted')) {
          
          debugPrint('Rate limit hit! Waiting 25 seconds before retrying...');
          await Future.delayed(const Duration(seconds: 25));
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Failed to generate content after automatic retries.');
  }
  // --- CONTENT POSTING FALLBACK VAULT ---
  static const Map<String, List<Map<String, String>>> _fallbackVault = {
    'Monday': [
      {
        "title": "Konsi's Trivia",
        "context": "general",
        "body": "Alam niyo ba na ang Angono ay tahanan ng 'Petroglyphs', ang pinakamatandang sining sa Pilipinas na nagmula pa sa Late Neolithic period? Ito ay patunay ng ating sinaunang galing sa sining.",
        "verse": "",
        "reflection": "Ang pagiging 'Art Capital' ay hindi lang titulo; ito ay tungkulin nating ingatan ang kasaysayan. Bilang inyong Konsi, isusulong ko ang pangangalaga sa ating mga cultural heritage sites.",
        "question": "Napuntahan mo na ba ang Petroglyphs? Ano ang naramdaman mo pagkakita rito? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Bayan Knowledge",
        "context": "general",
        "body": "Ang 'Higantes Festival' ay nagsimula bilang protesta ng mga taga-Angono laban sa mga mapang-aping asendero noon. Ang mga 'Higantes' ay simbolo ng ating pagkakaisa at mapanuring kaisipan.",
        "verse": "",
        "reflection": "Ang sining ay sandata rin ng ating boses. Naniniwala ako na ang kalayaan sa pagpapahayag ang nagbubuklod sa atin para sa mas maunlad na bukas.",
        "question": "Sino para sa iyo ang pinaka-click na karakter ng Higantes? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Konsi's Trivia",
        "context": "general",
        "body": "Kilala ang Angono sa 'Itik-Itik' dance, isang sayaw na hango sa galaw ng mga bibe sa lawa ng Laguna de Bay. Ito ay likha ni Cayetana Ranquin noong 1900s mula rito sa ating bayan.",
        "verse": "",
        "reflection": "Ang galing natin ay mula sa pagmamasid at pagpapahalaga sa ating kapaligiran. I committed to supporting our local folk arts and dancers.",
        "question": "Aling tradisyonal na sayaw ang paborito mong panoorin tuwing pista? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Bayan Knowledge",
        "context": "general",
        "body": "Ang ating Parokya ni San Clemente ay itinatag noong 1933. Ito ay hindi lamang simbahan, kundi saksi sa bawat tagumpay at hirap na pinagdaanan ng bawat pamilyang Angono.",
        "verse": "",
        "reflection": "Sa bawat pagbisita ko rito, naaalala ko na ang serbisyo ay isang spiritual mission. Ang pananampalataya ang gabay ko sa paglilingkod sa inyo.",
        "question": "Ano ang iyong pinakamahalagang alaala sa ating parokya? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      }
    ],
    'Saturday': [
      {
        "title": "Saturday Strength",
        "context": "general",
        "body": "\"A leader is one who knows the way, goes the way, and shows the way.\" - John C. Maxwell",
        "verse": "",
        "reflection": "Ang tunay na lider ay hindi lang nag-uutos; siya ay unang gumagalaw para sa bayan. Sa bawat project natin, sisiguraduhin kong kasama niyo ako sa field.",
        "question": "Paano ka nagpapakita ng leadership sa iyong simpleng paraan sa bahay o opisina? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Konsi's Wisdom",
        "context": "general",
        "body": "\"If your actions inspire others to dream more, learn more, do more and become more, you are a leader.\" - John Quincy Adams",
        "reflection": "Ang tagumpay ko ay kapag nakita kong kayo mismo ang nagpapakita ng inisyatibo para sa ating komunidad. Empowering Angono is my vision.",
        "question": "Sino ang taong pinaka-nag-inspire sa iyo na maging mas mabuting tao? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Saturday Strength",
        "context": "general",
        "body": "\"The quality of a leader is reflected in the standards they set for themselves.\" - Ray Kroc",
        "reflection": "I hold myself to the highest standard of integrity because you deserve nothing less. Transparency is the key to our progress.",
        "question": "Ano ang 'standard' mo pagdating sa serbisyo-publiko? Comment below! #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      }
    ],
    'Sunday': [
      {
        "title": "Sunday Blessing",
        "context": "general",
        "body": "Isang mapagpalang Linggo. Let us find peace in knowing that God's plan is always better than ours.",
        "verse": "Jeremiah 29:11: \"'For I know the plans I have for you,' declares the LORD, 'plans to prosper you and not to harm you, plans to give you hope and a future.'\"",
        "reflection": "Kahit may delay o hirap, naniniwala ako na may inihandang magandang bukas ang Panginoon para sa Angono. Trust the process.",
        "question": "Sa anong aspeto ng iyong buhay ka kailangang magtiwala sa plano ng Diyos ngayon? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Sunday Light",
        "context": "general",
        "body": "Focus on the positive today. Let your light shine before others.",
        "verse": "Matthew 5:16: \"In the same way, let your light shine before others, that they may see your good deeds and glorify your Father in heaven.\"",
        "reflection": "Ang bawat maliit na kabutihang ginagawa natin ay nagbibigay ng liwanag sa ating bayan. Be a beacon of hope for Angono.",
        "question": "Sino ang nagbigay sa iyo ng ngiti ngayong araw? Itag mo siya! #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      },
      {
        "title": "Sunday Blessing",
        "context": "general",
        "body": "Recharge your spirit this Sunday. God is our strength and our shield.",
        "verse": "Psalm 28:7: \"The LORD is my strength and my shield; my heart trusts in him, and he helps me.\"",
        "reflection": "Kapag pagod na sa trabaho o paglilingkod, sa Kanya tayo humuhugot ng lakas. He is our ultimate protector here in Rizal.",
        "question": "Anong verse ang nagpapalakas ng loob mo tuwing ikaw ay pagod? #SerbisyongTapatparasaLahat #KeepMovingAngono #SerbisyongMaePuso"
      }
    ],
    'Event': [
      {
        "title": "Municipal Event",
        "context": "general",
        "content": "Isang paanyaya mula sa inyong Sangguniang Bayan: Makilahok po tayo sa ating darating na kaganapan para sa ikabubuti ng ating Munisipalidad."
      }
    ]
  };

  /// Generate content post (Did You Know, Bible Verse, Inspirational Quote)
  static Future<Map<String, String>> generateContentPost(String prompt, String category, {DateTime? targetDate}) async {
    try {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) throw Exception('Network error');

      // Enhanced prompt for unique content variety
      final enrichedPrompt = """
$prompt

PERSONA:
- You are **Konsi Matthew Lagaya**, a young, approachable public servant from **Angono, Rizal**.
- Tone: Relevant, engaging, and medium-length.

STRICT VARIETY RULES:
1. **NEVER REPEAT** previous topics like Mahatma Gandhi, General Art Capital facts, or basic history if you can avoid it.
2. **MONDAY (TRIVIA)**: Focus on lesser-known Angono gems, the history of its residents, or deep cultural meaning. Make the fact "Indulgent" or "Rewarded knowledge".
3. **SATURDAY (WISDOM)**: Pick world-class leadership quotes from diverse figures (Seneca, Marcus Aurelius, modern tech CEOs, or Asian philosophers). Lesson must be felt.
4. **SUNDAY (BLESSING)**: Pick a bible verse that triggers sympathy or hope.

STRUCTURE:
- "body": The main content (Third Person/Objective).
- "verse": (For Sunday only).
- "reflection": (First Person/Konsi's personal voice). Link the content to community service in Angono.
- "question": Engaging query for the people.

Respond ONLY in JSON:
{ 
  "title": "Unique Title", 
  "body": "Main content",
  "verse": "Reference & Text",
  "reflection": "Personal voice here",
  "question": "Engaging query"
}
""";

      final model = _createModel();
      final response = await model.generateContent([Content.text(enrichedPrompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response');
      }

      final Map<String, dynamic> parsed = jsonDecode(response.text!.trim());
      return parsed.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return await _getRotatedFallback(category, targetDate: targetDate);
    }
  }

  static Future<Map<String, String>> _getRotatedFallback(String category, {DateTime? targetDate}) async {
    final fullVault = _fallbackVault[category] ?? _fallbackVault['Monday']!;
    
    // Week-Aware Filtering for 2026
    List<Map<String, String>> contextualVault = [];
    
    if (targetDate != null) {
      final month = targetDate.month;

      if (month == 4) { // APRIL 2026
        // April 1-5 is Holy Week/Easter in 2026
        if (targetDate.day <= 5) {
          contextualVault = fullVault.where((e) => e['context'] == 'holyWeek').toList();
        } 
        // Araw ng Kagitingan is April 9 (Week 2)
        else if (targetDate.day >= 6 && targetDate.day <= 12) {
          contextualVault = fullVault.where((e) => e['context'] == 'kagitingan').toList();
        }
        // Earth Day is April 22 (Week 4)
        else if (targetDate.day >= 19 && targetDate.day <= 25) {
          contextualVault = fullVault.where((e) => e['context'] == 'earthDay').toList();
        }
      }
    }
    
    // Fall back to general if no specific context matches
    if (contextualVault.isEmpty) {
      contextualVault = fullVault.where((e) => e['context'] == 'general' || e['context'] == null).toList();
    }
    
    if (contextualVault.isEmpty) contextualVault = fullVault;

    final lastIndex = await StorageService.getLastFallbackIndex(category);
    int nextIndex = (lastIndex + 1) % contextualVault.length;
    await StorageService.setLastFallbackIndex(category, nextIndex);
    
    return contextualVault[nextIndex];
  }

  // --- PARSERS ---

  static List<ScheduleEvent> _parseScheduleResponse(String response) {
    try {
      final List<dynamic> jsonList = jsonDecode(response.trim());
      return jsonList
          .map((json) => ScheduleEvent.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw Exception('Failed to parse schedule response: $e\nResponse: $response');
    }
  }

  static List<Solicitation> _parseSolicitationResponse(String response) {
    try {
      final List<dynamic> jsonList = jsonDecode(response.trim());
      return jsonList
          .map((json) => Solicitation.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw Exception('Failed to parse solicitation response: $e\nResponse: $response');
    }
  }

  // --- HELPERS ---

  static String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
