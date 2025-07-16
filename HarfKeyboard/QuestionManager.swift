import Foundation

struct Question: Codable {
    let letter: String
    let question: String
}

class QuestionManager {
    private var questions: [String: String] = [:]

    init() {
        loadQuestions()
    }

    private func loadQuestions() {
        // Try to load from JSON file first
        if let url = Bundle.main.url(forResource: "questions", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Question].self, from: data)
                for q in decoded {
                    questions[q.letter] = q.question
                }
                print("✅ Questions loaded from JSON for keyboard: \(decoded.count) questions")
            } catch {
                print("⚠️ Failed to load questions.json for keyboard: \(error)")
                loadDefaultQuestions()
            }
        } else {
            print("⚠️ questions.json not found for keyboard, using default questions")
            loadDefaultQuestions()
        }
    }
    
    private func loadDefaultQuestions() {
        questions = [
            "ا": "ما اسم عاصمة المملكة العربية السعودية؟",
            "ب": "اسم نهر مشهور في مصر يبدأ بحرف الباء؟",
            "ت": "شيء نأكله في الصباح يبدأ بحرف التاء؟",
            "ث": "حيوان يبدأ بحرف الثاء؟",
            "ج": "مدينة مشهورة في المغرب تبدأ بحرف الجيم؟",
            "ح": "اسم شهر هجري يبدأ بحرف الحاء؟",
            "خ": "شيء نستخدمه في المطبخ يبدأ بحرف الخاء؟",
            "د": "اسم دولة عربية تبدأ بحرف الدال؟",
            "ذ": "شيء له ذيل يبدأ بحرف الذال؟",
            "ر": "اسم نهر في العراق يبدأ بحرف الراء؟",
            "ز": "فاكهة تبدأ بحرف الزاي؟",
            "س": "اسم عاصمة سوريا يبدأ بحرف السين؟",
            "ش": "شيء نستخدمه في الشتاء يبدأ بحرف الشين؟",
            "ص": "اسم صلاة تبدأ بحرف الصاد؟",
            "ض": "حيوان يبدأ بحرف الضاد؟",
            "ط": "شيء نراه في السماء يبدأ بحرف الطاء؟",
            "ظ": "شيء يصدر ظلاً يبدأ بحرف الظاء؟",
            "ع": "اسم عاصمة عربية تبدأ بحرف العين؟",
            "غ": "شيء نأكله في الغداء يبدأ بحرف الغين؟",
            "ف": "اسم فاكهة تبدأ بحرف الفاء؟",
            "ق": "اسم دولة تبدأ بحرف القاف؟",
            "ك": "شيء نكتبه يبدأ بحرف الكاف؟",
            "ل": "اسم نبات يبدأ بحرف اللام؟",
            "م": "اسم مدينة في مصر تبدأ بحرف الميم؟",
            "ن": "اسم نهر في أفريقيا يبدأ بحرف النون؟",
            "ه": "شيء نستخدمه في الحمام يبدأ بحرف الهاء؟",
            "و": "اسم ولد يبدأ بحرف الواو؟",
            "ي": "اسم بنت يبدأ بحرف الياء؟"
        ]
        print("✅ Default questions loaded for keyboard: \(questions.count) questions")
    }

    func question(for letter: String) -> String? {
        return questions[letter] ?? "سؤال حول حرف \(letter)؟"
    }
} 