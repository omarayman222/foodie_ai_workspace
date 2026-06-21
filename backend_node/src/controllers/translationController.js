const Groq = require('groq-sdk');
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// Pull JSON out of the model's reply even if it wraps it in markdown fences
function extractJson(text) {
    const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    const src = fenced ? fenced[1] : text;
    // Find the first { … } block
    const start = src.indexOf('{');
    const end   = src.lastIndexOf('}');
    if (start === -1 || end === -1) throw new Error('No JSON object found in response');
    return JSON.parse(src.slice(start, end + 1));
}

exports.translate = async (req, res) => {
    try {
        const { texts, targetLang = 'Arabic' } = req.body;

        if (!texts || !Array.isArray(texts) || texts.length === 0) {
            return res.status(400).json({ error: 'texts array is required.' });
        }
        if (texts.length > 100) {
            return res.status(400).json({ error: 'Maximum 100 strings per request.' });
        }

        // Index each step so the model can't accidentally merge or skip them
        const numbered = texts.map((t, i) => `${i + 1}. ${t}`).join('\n');

        const isEgyptian = targetLang.toLowerCase().includes('egyptian') || targetLang.includes('مصر');

        const egyptianPrompt = isEgyptian ? `You are an Egyptian home cook translating a recipe into your natural everyday spoken language — Egyptian colloquial Arabic (عامية مصرية) as heard in Cairo kitchens.

RULES — follow every one of them:
1. Write ONLY in Egyptian colloquial Arabic. NEVER write in Modern Standard Arabic (فصحى).
2. Use natural spoken Egyptian sentence structure and connectors: "وبعدين", "لحد ما", "من غير ما", "على طول", "خليه", "اديه", "هيبقى".
3. Egyptian kitchen vocabulary — ALWAYS use these, never the formal alternatives:
   • حط / حطي  (not ضع / ضعي)
   • ضيف / زود  (not أضف)
   • قلب / اقلب  (not اخلط / امزج)
   • سخن / حمي  (not أسخن)
   • صب / اصب  (not اسكب / اسقِ)
   • هات / جيب  (not احضر)
   • سيب / خليه  (not اترك)
   • شرح / اقطع  (not قطع)
   • برّ / برّد  (not اترك يبرد)
   • الفرن  → "الفرن", baking pan → "الصينية", pot → "الحلة", pan → "الطاسة", bowl → "وعا / طبق"
   • دقيقة → "دقيقة", درجة حرارة → "درجة" أو "درجة حرارة"
4. Translate temperatures, quantities, and timings accurately — do NOT alter numbers.
5. Keep steps concise and natural, as if you are speaking directly to someone in the kitchen.
6. Do NOT add commentary, do NOT use formal connectives like "ثم" or "بعد ذلك" — use "وبعدين" instead.

EXAMPLES of Egyptian colloquial cooking style:
  English: "Preheat the oven to 200°C." → "سخن الفرن على 200 درجة الأول."
  English: "Add the onion and stir until golden." → "ضيف البصل وقلبه لحد ما يبقى دهبي."
  English: "Pour the mixture into a greased baking pan." → "صب الخليط في الصينية المدهونة."
  English: "Cover and let it simmer for 20 minutes." → "غطيه وسيبه يتهرى على نار هادية 20 دقيقة."
  English: "Season with salt and pepper to taste." → "بهره بالملح والفلفل على حسب دوقك."
  English: "Bring a pot of salted water to a boil." → "جيب حلة ميه مملحة وخليها تغلي."
  English: "Chop the garlic finely." → "اقطع التوم ناعم."
  English: "Remove from heat and allow to cool." → "شيله من على النار وسيبه يبرد شوية."
  English: "Bake for 30 minutes until golden." → "حطه في الفرن 30 دقيقة لحد ما يبقى دهبي."
  English: "Mix flour, sugar, and butter together." → "اخلط الدقيق والسكر والزبدة مع بعض كويس."

Now translate the following numbered cooking steps using this exact style.
Return a JSON object with a single key "translations" whose value is an array of translated strings in the SAME order and count as the input.
Do NOT include step numbers in the translated strings. No markdown, no extra text.

Input (${texts.length} steps):
${numbered}` : `You are a professional culinary translator.
Translate the following numbered cooking steps to ${targetLang}.
Return a JSON object with a single key "translations" whose value is an array of the translated strings, in the SAME order and count as the input.
Do NOT include the step numbers in the translated strings.
Do NOT add any extra text, commentary, or markdown outside the JSON.

Input (${texts.length} steps):
${numbered}`;

        const prompt = egyptianPrompt;

        const response = await groq.chat.completions.create({
            messages: [{ role: 'user', content: prompt }],
            model: 'llama-3.3-70b-versatile',
            temperature: 0.1,
            max_tokens: 6000,
        });

        const raw = response.choices[0].message.content;
        console.log('[translate] raw response length:', raw.length);

        let parsed;
        try {
            parsed = extractJson(raw);
        } catch (parseErr) {
            console.error('[translate] JSON parse failed:', parseErr.message, '\nraw:', raw.slice(0, 300));
            return res.status(500).json({ error: 'Could not parse translation response. Please retry.' });
        }

        let translations = parsed.translations;

        if (!Array.isArray(translations)) {
            console.error('[translate] translations field is not an array:', typeof translations);
            return res.status(500).json({ error: 'Unexpected translation format. Please retry.' });
        }

        // If the model returns fewer strings than input, pad with originals so the app doesn't break
        if (translations.length < texts.length) {
            console.warn(`[translate] count mismatch: got ${translations.length}, expected ${texts.length} — padding with originals`);
            while (translations.length < texts.length) {
                translations.push(texts[translations.length]);
            }
        }

        // Trim to exact length in case of extras
        translations = translations.slice(0, texts.length);

        res.status(200).json({ translations });

    } catch (error) {
        console.error('[translate] error:', error.message || error);
        res.status(500).json({ error: `Translation failed: ${error.message || 'unknown error'}` });
    }
};
