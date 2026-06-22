const Groq = require('groq-sdk');
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// Pull JSON out of the model's reply even if it wraps it in markdown fences
function extractJson(text) {
    const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    const src = fenced ? fenced[1] : text;
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

        const numbered = texts.map((t, i) => `${i + 1}. ${t}`).join('\n');

        const isEgyptian = targetLang.toLowerCase().includes('egyptian') || targetLang.includes('مصر');

        // ── Egyptian Arabic ────────────────────────────────────────────────
        // system: persona + hard vocabulary rules (Arabic)
        // user:   14 worked examples + the actual steps
        const messages = isEgyptian ? [
            {
                role: 'system',
                content: [
                    'أنت طنط فوزية — ست بيت مصرية من القاهرة بتشرحي خطوات الطبخ لبنتك بالعامية المصرية الخالصة.',
                    '',
                    'قواعد صارمة:',
                    '• عامية مصرية فقط — ممنوع أي كلمة فصحى خالص.',
                    '• "حطي" مش "ضعي". "ضيفي/زودي" مش "أضيفي". "قلبي" مش "اخلطي". "صبي" مش "اسكبي". "جيبي" مش "احضري". "سيبيه" مش "اتركيه". "شيليه" مش "أزيليه".',
                    '• الفراخ (مش الدجاج). الحلة (pot). الطاسة (pan). الصينية (baking tray). وعا (bowl). ناعم (finely). دهبي (golden). كويس (well/good).',
                    '• وصلي بـ "وبعدين", "لحد ما", "من غير ما", "وخليه". مش "ثم" أو "بعد ذلك".',
                    '• الأرقام والكميات ودرجات الحرارة تبقى صح بالظبط — ماتغيريش أي رقم.',
                    '• كل خطوة جملة أو جملتين بالكثير — مباشرة وواضحة.'
                ].join('\n')
            },
            {
                role: 'user',
                content: [
                    'ترجمي الخطوات دي للعامية المصرية.',
                    'ردي بـ JSON بس: {"translations": ["..."]} — نفس الترتيب، نفس العدد، من غير أرقام جوا الترجمة.',
                    '',
                    'أمثلة على الأسلوب:',
                    '"Bring a large pot of salted water to a boil." → "جيبي حلة كبيرة ميه مملحة وخليها تغلي كويس."',
                    '"Add the onion and stir until golden brown." → "ضيفي البصل وقلبيه لحد ما يبقى دهبي."',
                    '"Season with salt, pepper, and cumin to taste." → "بهريه بالملح والفلفل والكمون على حسب دوقك."',
                    '"Cover and let it simmer on low heat for 20 minutes." → "غطيه وسيبيه يتهرى على نار هادية 20 دقيقة."',
                    '"Remove from heat and allow to cool slightly." → "شيليه من على النار وسيبيه يبرد شوية."',
                    '"Preheat the oven to 180°C." → "سخني الفرن على 180 درجة الأول."',
                    '"Chop the tomatoes finely and set aside." → "اقطعي الطماطم ناعم وحطيهم جنب."',
                    '"Pour the sauce over the chicken and bake for 45 minutes." → "صبي الصلصة على الفراخ وحطيه في الفرن 45 دقيقة."',
                    '"Mix flour, sugar, and butter until smooth." → "اخلطي الدقيق والسكر والزبدة مع بعض لحد ما يبقى ناعم."',
                    '"Let the dough rest for 1 hour." → "سيبي العجينة ترتاح ساعة."',
                    '"Fry until crispy and golden." → "احمريه لحد ما يبقى مقرمش ودهبي."',
                    '"Fold gently so you don\'t deflate the batter." → "اطويه بهدوء من غير ما تكسري الهوا جوه."',
                    '"Drain the pasta and reserve some pasta water." → "صفي المكرونة واحتفظي بشوية من ميت السلق."',
                    '"Taste and adjust seasoning." → "دوقيه وظبطي التتبيلة على حسب دوقك."',
                    '',
                    `الخطوات (${texts.length}):`,
                    numbered
                ].join('\n')
            }
        ] : [
            {
                role: 'user',
                content: `You are a professional culinary translator. Translate the following numbered cooking steps to ${targetLang}.
Return ONLY a JSON object: {"translations": ["step 1", "step 2", ...]} in the SAME order and count as the input. No step numbers inside translations. No markdown.

Input (${texts.length} steps):
${numbered}`
            }
        ];

        const response = await groq.chat.completions.create({
            messages,
            model: 'llama-3.1-8b-instant',
            temperature: 0.15,
            max_tokens: 1500,
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

        if (translations.length < texts.length) {
            console.warn(`[translate] count mismatch: got ${translations.length}, expected ${texts.length} — padding with originals`);
            while (translations.length < texts.length) {
                translations.push(texts[translations.length]);
            }
        }

        translations = translations.slice(0, texts.length);

        res.status(200).json({ translations });

    } catch (error) {
        console.error('[translate] error:', error.message || error);
        res.status(500).json({ error: `Translation failed: ${error.message || 'unknown error'}` });
    }
};
