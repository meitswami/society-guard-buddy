import fs from 'fs';

const path = 'src/i18n/translations.ts';
const src = fs.readFileSync(path, 'utf8');

const pairs = [
  // Fix awkward doubles / bad compositions from first pass
  ['मुख्य पृष्ठ मुख्य पटल', 'मुख्य पटल'],
  ['पूरा मार्गदर्शन के लिए मार्गदर्शन दबाएँ', 'पूरा मार्गदर्शन देखने के लिए दबाएँ'],
  ['प्रतीक चिह्न पता', 'प्रतीक-चिह्न का पता'],
  ['निर्धारित की गई सीमा', 'निर्धारित सीमा'],

  // Remaining common Hinglish in hi strings
  ['आगंतुक लॉग', 'आगंतुक अभिलेख'],
  [' लॉग में', ' अभिलेख में'],
  ['नंबरिंग फ़ील्ड', 'क्रमांकन क्षेत्र'],
  ['रेफरल कोड', 'संदर्भ कोड'],
  ['ब्लॉक्स / विंग', 'खंड / विंग'],
  ['पिनकोड', 'पिन कोड'],
  ['कंसोल', 'नियंत्रण पटल'],
  ['रोटेशन', 'आवर्तन'],
  ['रिफ्रेशर', 'पुनरावलोकन'],
  ['बैकअप', 'सुरक्षा प्रति'],
  ['ब्रांड-पहचान', 'ब्रांड पहचान'],
  ['सुपाबेस पता (यूआरएल)', 'सुपाबेस पता'],
  ['डेटाबेस', 'आँकड़ा भंडार'],
  ['नेटवर्क', 'संजाल'],
  ['कार्ड', 'पत्रक'],
  ['ओटीपी पास', 'ओटीपी प्रवेश पत्र'],
  ['लोड हो रहा है', 'लाया जा रहा है'],
  ['प्लेटफ़ॉर्म', 'मंच'],
  ['ईमेल', 'ई-मेल'],
];

function transformHi(s) {
  let out = s;
  for (const [a, b] of pairs) out = out.split(a).join(b);
  return out;
}

let result = '';
let i = 0;
while (i < src.length) {
  if (src.startsWith("hi: '", i)) {
    result += "hi: '";
    i += 5;
    let content = '';
    while (i < src.length) {
      if (src[i] === '\\') {
        content += src[i] + (src[i + 1] || '');
        i += 2;
        continue;
      }
      if (src[i] === "'") break;
      content += src[i];
      i += 1;
    }
    result += transformHi(content);
    if (i < src.length) {
      result += src[i];
      i += 1;
    }
    continue;
  }
  result += src[i];
  i += 1;
}

fs.writeFileSync(path, result);
console.log('polish done');
