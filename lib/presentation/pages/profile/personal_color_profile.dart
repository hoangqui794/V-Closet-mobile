import 'package:flutter/material.dart';

class PersonalColorSwatch {
  final String name;
  final Color color;

  const PersonalColorSwatch(this.name, this.color);
}

class FabricSuggestion {
  final String name;
  final String note;
  final List<Color> previewColors;

  const FabricSuggestion({
    required this.name,
    required this.note,
    required this.previewColors,
  });
}

class PersonalColorProfile {
  final String id;
  final String title;
  final String subtitle;
  final String mainDescription;
  final String bestColorDescription;
  final String fabricDescription;
  final String avoidDescription;
  final List<String> traits;
  final List<PersonalColorSwatch> bestColors;
  final List<PersonalColorSwatch> avoidColors;
  final List<FabricSuggestion> fabrics;
  final List<Color> wheelColors;

  const PersonalColorProfile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.mainDescription,
    required this.bestColorDescription,
    required this.fabricDescription,
    required this.avoidDescription,
    required this.traits,
    required this.bestColors,
    required this.avoidColors,
    required this.fabrics,
    required this.wheelColors,
  });

  static PersonalColorProfile resolve({
    required String? skinTone,
    required String? colorPref,
    required String? stylePref,
  }) {
    final skin = skinTone ?? 'trung_binh';
    final color = colorPref ?? 'trung_tinh';
    final style = stylePref ?? 'casual';

    if (skin == 'toi') {
      return color == 'mau_noi' ? brightWinter : deepWinter;
    }

    if (skin == 'ngam') {
      if (color == 'mau_noi') return brightWinter;
      if (color == 'toi_mau') return deepWinter;
      if (color == 'pastel' && style != 'cong_so') return warmSpring;
      return warmAutumn;
    }

    if (skin == 'sang') {
      if (color == 'mau_noi') return brightWinter;
      if (color == 'toi_mau') return coolSummer;
      if (color == 'pastel') return lightSpring;
      return warmSpring;
    }

    if (color == 'pastel' || color == 'mau_noi') return warmSpring;
    if (color == 'toi_mau') return softSummer;
    return warmAutumn;
  }

  static const warmSpring = PersonalColorProfile(
    id: 'warm_spring',
    title: 'Mùa Xuân Ấm',
    subtitle: 'Tươi sáng, ấm áp và sống động',
    mainDescription:
        'Bạn tỏa sáng trong những màu sắc tựa nắng sớm: trong trẻo, rạng rỡ và có độ ấm nhẹ. Các gam màu quá xám hoặc quá lạnh dễ làm da trông thiếu sức sống; ngược lại, sắc đào, vàng bơ, xanh non và kem ấm giúp tổng thể bừng sáng.',
    bestColorDescription:
        'Bảng màu phù hợp nhất với bạn gồm đào, san hô, mơ, vàng nhạt, be vàng, trắng ngà, xanh bạc hà và xanh ngọc lam. Khi chọn màu trung tính, hãy ưu tiên trắng ngà, màu lạc đà hoặc nâu rám nắng nhẹ thay vì xám lạnh.',
    fabricDescription:
        'Bạn hợp với các loại vải nhẹ, thoáng và tự nhiên. Cotton, linen mềm, lụa, voan và len dệt kim mịn giúp giữ vẻ ngoài tươi sáng mà vẫn mềm mại. Nên chọn bề mặt có độ bóng nhẹ hoặc độ rũ tự nhiên.',
    avoidDescription:
        'Hạn chế đen tuyền, xám chì, tím lạnh, burgundy quá sâu và trắng tinh. Những màu này dễ tạo độ tương phản nặng, làm mất sự ấm áp tự nhiên của làn da.',
    traits: ['Ấm', 'Tươi', 'Trong trẻo', 'Nhẹ nhàng'],
    bestColors: [
      PersonalColorSwatch('Trắng ngà', Color(0xFFFFF4DD)),
      PersonalColorSwatch('Kem ấm', Color(0xFFFFEBC2)),
      PersonalColorSwatch('Be mật ong', Color(0xFFEBC98E)),
      PersonalColorSwatch('Camel sáng', Color(0xFFCFA16A)),
      PersonalColorSwatch('Đào', Color(0xFFFFA36C)),
      PersonalColorSwatch('Mơ', Color(0xFFFFB36B)),
      PersonalColorSwatch('Vàng bơ', Color(0xFFFFE77A)),
      PersonalColorSwatch('Vàng nắng', Color(0xFFFFD84D)),
      PersonalColorSwatch('San hô tươi', Color(0xFFFF7F6E)),
      PersonalColorSwatch('Hồng salmon', Color(0xFFFF9A8B)),
      PersonalColorSwatch('Đỏ cà chua', Color(0xFFE94B35)),
      PersonalColorSwatch('Xanh non', Color(0xFF96D286)),
      PersonalColorSwatch('Xanh táo', Color(0xFF8CCF5F)),
      PersonalColorSwatch('Mint ấm', Color(0xFFA6E6B8)),
      PersonalColorSwatch('Ngọc lam', Color(0xFF55C7C2)),
      PersonalColorSwatch('Aqua sáng', Color(0xFF7EDFD6)),
    ],
    avoidColors: [
      PersonalColorSwatch('Đen tuyền', Color(0xFF111111)),
      PersonalColorSwatch('Xám lạnh', Color(0xFF8E96A3)),
      PersonalColorSwatch('Tím lạnh', Color(0xFF6F5B8F)),
      PersonalColorSwatch('Trắng tinh', Color(0xFFFFFFFF)),
      PersonalColorSwatch('Burgundy sâu', Color(0xFF5B1026)),
      PersonalColorSwatch('Xanh băng', Color(0xFFCDEEFF)),
      PersonalColorSwatch('Mauve bụi', Color(0xFFB98BA5)),
      PersonalColorSwatch('Navy đen', Color(0xFF0F1B33)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Cotton mềm',
        note: 'Sạch, nhẹ, dễ mặc hằng ngày.',
        previewColors: [Color(0xFFFFFFFF), Color(0xFFF7EEDC)],
      ),
      FabricSuggestion(
        name: 'Linen sáng',
        note: 'Tự nhiên, thoáng và có độ rũ.',
        previewColors: [Color(0xFFF4E6C5), Color(0xFFE6C989)],
      ),
      FabricSuggestion(
        name: 'Lụa/voan',
        note: 'Bóng nhẹ, làm màu ấm rạng rỡ hơn.',
        previewColors: [Color(0xFFFFF2CF), Color(0xFFFFB79B)],
      ),
    ],
    wheelColors: [
      Color(0xFFFFE95A),
      Color(0xFFFFA35F),
      Color(0xFFF2A4A0),
      Color(0xFF8DD49A),
      Color(0xFF72C7C2),
    ],
  );

  static const lightSpring = PersonalColorProfile(
    id: 'light_spring',
    title: 'Mùa Xuân Sáng',
    subtitle: 'Nhẹ, trong và rạng rỡ',
    mainDescription:
        'Bạn hợp với các màu sáng, ít pha xám và có cảm giác mềm như ánh nắng đầu ngày. Bảng màu càng nhẹ và sạch, làn da càng trông tươi hơn.',
    bestColorDescription:
        'Ưu tiên hồng phấn ấm, kem sữa, xanh mint, vàng vanilla, đào nhạt và xanh trời sáng. Các gam trung tính nên là ivory, beige sáng hoặc camel nhạt.',
    fabricDescription:
        'Các chất liệu mềm, mịn và ít nặng như cotton poplin, lụa mỏng, chiffon, linen mịn và knit mảnh giúp giữ tổng thể nhẹ nhàng.',
    avoidDescription:
        'Tránh màu quá trầm như nâu chocolate, đen đặc, xanh navy dày và đỏ rượu vì dễ kéo gương mặt xuống.',
    traits: ['Sáng', 'Nhẹ', 'Ấm nhẹ', 'Mềm'],
    bestColors: [
      PersonalColorSwatch('Hồng phấn', Color(0xFFFFC7D1)),
      PersonalColorSwatch('Kem sữa', Color(0xFFFFF0C8)),
      PersonalColorSwatch('Mint', Color(0xFFA9E7C3)),
      PersonalColorSwatch('Đào nhạt', Color(0xFFFFC29B)),
      PersonalColorSwatch('Xanh trời', Color(0xFFAADCF6)),
    ],
    avoidColors: [
      PersonalColorSwatch('Đen', Color(0xFF111111)),
      PersonalColorSwatch('Nâu đậm', Color(0xFF4E342E)),
      PersonalColorSwatch('Navy sâu', Color(0xFF17213F)),
      PersonalColorSwatch('Đỏ rượu', Color(0xFF6D1B2A)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Poplin',
        note: 'Gọn, sáng và trẻ trung.',
        previewColors: [Color(0xFFFFFFFF), Color(0xFFEAF7FF)],
      ),
      FabricSuggestion(
        name: 'Chiffon',
        note: 'Mỏng nhẹ, hợp bảng màu pastel.',
        previewColors: [Color(0xFFFFE4EA), Color(0xFFFFF5D6)],
      ),
      FabricSuggestion(
        name: 'Knit mảnh',
        note: 'Mềm, thoải mái và không nặng.',
        previewColors: [Color(0xFFF3EBDD), Color(0xFFDCEFD9)],
      ),
    ],
    wheelColors: [
      Color(0xFFFFF0C8),
      Color(0xFFFFC29B),
      Color(0xFFFFC7D1),
      Color(0xFFA9E7C3),
      Color(0xFFAADCF6),
    ],
  );

  static const warmAutumn = PersonalColorProfile(
    id: 'warm_autumn',
    title: 'Mùa Thu Ấm',
    subtitle: 'Ấm, trầm và tự nhiên',
    mainDescription:
        'Bạn tỏa sáng trong các sắc màu đất có chiều sâu: camel, olive, gạch nung và vàng mù tạt. Những màu này làm da trông khỏe, ấm và sang hơn.',
    bestColorDescription:
        'Bảng màu hợp nhất gồm olive, terracotta, camel, chocolate ấm, vàng mù tạt và kem ngà. Các màu trung tính nên có sắc nâu hoặc vàng thay vì xanh/xám lạnh.',
    fabricDescription:
        'Da thuộc mềm, suede, denim xanh ấm, linen dày vừa, cotton thô và len sợi tự nhiên rất hợp với năng lượng Mùa Thu Ấm.',
    avoidDescription:
        'Tránh neon lạnh, trắng tinh, xám bạc, hồng tím lạnh và xanh băng vì dễ làm da xỉn hoặc thiếu độ ấm.',
    traits: ['Ấm', 'Đất', 'Tự nhiên', 'Sâu vừa'],
    bestColors: [
      PersonalColorSwatch('Olive', Color(0xFF6B7A3A)),
      PersonalColorSwatch('Terracotta', Color(0xFFC85A3A)),
      PersonalColorSwatch('Camel', Color(0xFFC19762)),
      PersonalColorSwatch('Mù tạt', Color(0xFFD6A321)),
      PersonalColorSwatch('Kem ngà', Color(0xFFF4E2B8)),
    ],
    avoidColors: [
      PersonalColorSwatch('Xám bạc', Color(0xFFB8C0CC)),
      PersonalColorSwatch('Trắng tinh', Color(0xFFFFFFFF)),
      PersonalColorSwatch('Hồng tím', Color(0xFFD9B6E8)),
      PersonalColorSwatch('Neon lạnh', Color(0xFFB7FF00)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Suede',
        note: 'Mềm, ấm và có chiều sâu.',
        previewColors: [Color(0xFFC19762), Color(0xFF8A5A37)],
      ),
      FabricSuggestion(
        name: 'Denim ấm',
        note: 'Khỏe khoắn, dễ phối earth tone.',
        previewColors: [Color(0xFF375A64), Color(0xFF6F8D91)],
      ),
      FabricSuggestion(
        name: 'Len tự nhiên',
        note: 'Tạo cảm giác sang và ấm.',
        previewColors: [Color(0xFFE6D1A8), Color(0xFFB08C5A)],
      ),
    ],
    wheelColors: [
      Color(0xFFD6A321),
      Color(0xFFC85A3A),
      Color(0xFFC19762),
      Color(0xFF6B7A3A),
      Color(0xFF8A5A37),
    ],
  );

  static const softSummer = PersonalColorProfile(
    id: 'soft_summer',
    title: 'Mùa Hè Dịu',
    subtitle: 'Dịu, lạnh nhẹ và thanh lịch',
    mainDescription:
        'Bạn hợp với bảng màu có sắc lạnh nhẹ và được làm mềm bởi một chút xám. Tổng thể đẹp nhất khi màu không quá chói, không quá tối.',
    bestColorDescription:
        'Ưu tiên dusty rose, mauve, xanh xám, lavender dịu, sage lạnh và taupe. Các màu trung tính nên là xám ấm nhẹ, kem lạnh hoặc nâu hồng nhạt.',
    fabricDescription:
        'Chọn viscose, lụa mờ, cotton mịn, knit mềm và linen pha để màu sắc trông dịu, không bị gắt.',
    avoidDescription:
        'Tránh cam cháy, vàng mù tạt, neon, đen quá đặc và trắng tinh có độ tương phản cao.',
    traits: ['Dịu', 'Lạnh nhẹ', 'Ít tương phản', 'Thanh'],
    bestColors: [
      PersonalColorSwatch('Dusty rose', Color(0xFFD9A4A8)),
      PersonalColorSwatch('Mauve', Color(0xFFB58AA5)),
      PersonalColorSwatch('Xanh xám', Color(0xFF8FA7B2)),
      PersonalColorSwatch('Sage lạnh', Color(0xFFA8B8A0)),
      PersonalColorSwatch('Taupe', Color(0xFFC3B2A3)),
    ],
    avoidColors: [
      PersonalColorSwatch('Cam cháy', Color(0xFFD95D27)),
      PersonalColorSwatch('Mù tạt', Color(0xFFD6A321)),
      PersonalColorSwatch('Neon', Color(0xFFFF2BD6)),
      PersonalColorSwatch('Đen đặc', Color(0xFF111111)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Lụa mờ',
        note: 'Sang nhưng không quá bóng.',
        previewColors: [Color(0xFFD9A4A8), Color(0xFFCBBBC7)],
      ),
      FabricSuggestion(
        name: 'Viscose',
        note: 'Rũ mềm, hợp màu dịu.',
        previewColors: [Color(0xFFA8B8A0), Color(0xFFE4E2DD)],
      ),
      FabricSuggestion(
        name: 'Knit mềm',
        note: 'Giữ cảm giác êm và thanh.',
        previewColors: [Color(0xFFC3B2A3), Color(0xFF8FA7B2)],
      ),
    ],
    wheelColors: [
      Color(0xFFD9A4A8),
      Color(0xFFB58AA5),
      Color(0xFF8FA7B2),
      Color(0xFFA8B8A0),
      Color(0xFFC3B2A3),
    ],
  );

  static const coolSummer = PersonalColorProfile(
    id: 'cool_summer',
    title: 'Mùa Hè Lạnh',
    subtitle: 'Mát, mềm và tinh tế',
    mainDescription:
        'Bạn hợp với những gam lạnh vừa phải, có độ trong dịu và cảm giác tinh tế. Màu xanh xám, hồng lạnh và tím lavender giúp da trông sạch, sáng và cân bằng.',
    bestColorDescription:
        'Các màu đẹp nhất gồm xanh powder, rose lạnh, lavender, xanh denim nhạt, bạc mềm và trắng ngọc trai.',
    fabricDescription:
        'Cotton mịn, lụa mờ, satin ít bóng, denim sáng và vải dệt mềm là lựa chọn an toàn cho bảng màu lạnh dịu.',
    avoidDescription:
        'Hạn chế cam đào đậm, vàng nghệ, nâu gạch và các màu quá nóng vì dễ làm da trông đỏ hoặc xỉn.',
    traits: ['Lạnh', 'Mềm', 'Sáng vừa', 'Tinh tế'],
    bestColors: [
      PersonalColorSwatch('Powder blue', Color(0xFFB7D3E8)),
      PersonalColorSwatch('Rose lạnh', Color(0xFFE0A7B7)),
      PersonalColorSwatch('Lavender', Color(0xFFC7B7E8)),
      PersonalColorSwatch('Denim nhạt', Color(0xFF7F9DB5)),
      PersonalColorSwatch('Ngọc trai', Color(0xFFF4F1EE)),
    ],
    avoidColors: [
      PersonalColorSwatch('Cam đào đậm', Color(0xFFFF8B4D)),
      PersonalColorSwatch('Vàng nghệ', Color(0xFFE0A000)),
      PersonalColorSwatch('Nâu gạch', Color(0xFF9B4A2F)),
      PersonalColorSwatch('Olive vàng', Color(0xFF808000)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Satin mờ',
        note: 'Mượt nhưng vẫn dịu mắt.',
        previewColors: [Color(0xFFF4F1EE), Color(0xFFB7D3E8)],
      ),
      FabricSuggestion(
        name: 'Denim sáng',
        note: 'Tự nhiên, mát và dễ phối.',
        previewColors: [Color(0xFF7F9DB5), Color(0xFFC8DAE7)],
      ),
      FabricSuggestion(
        name: 'Cotton mịn',
        note: 'Sạch, nhẹ và không quá nổi.',
        previewColors: [Color(0xFFFFFFFF), Color(0xFFE0A7B7)],
      ),
    ],
    wheelColors: [
      Color(0xFFB7D3E8),
      Color(0xFFE0A7B7),
      Color(0xFFC7B7E8),
      Color(0xFF7F9DB5),
      Color(0xFFF4F1EE),
    ],
  );

  static const deepWinter = PersonalColorProfile(
    id: 'deep_winter',
    title: 'Mùa Đông Sâu',
    subtitle: 'Sâu, sắc nét và quyền lực',
    mainDescription:
        'Bạn hợp với bảng màu có chiều sâu và độ tương phản rõ. Đen, trắng, xanh navy, đỏ rượu và emerald giúp gương mặt trông sắc nét, sang và có điểm nhấn.',
    bestColorDescription:
        'Chọn đen, trắng sáng, navy, burgundy, emerald, tím than và bạc lạnh. Những gam màu sâu nhưng sạch sẽ là “vũ khí” mạnh nhất của bạn.',
    fabricDescription:
        'Da bóng, satin, denim đậm, wool mịn và cotton đứng phom giúp các màu sâu lên đẹp, gọn và cao cấp.',
    avoidDescription:
        'Tránh be vàng nhạt, cam pastel, vàng bơ và màu quá bụi vì có thể làm tổng thể thiếu lực.',
    traits: ['Sâu', 'Lạnh', 'Tương phản', 'Sắc nét'],
    bestColors: [
      PersonalColorSwatch('Đen', Color(0xFF111111)),
      PersonalColorSwatch('Trắng sáng', Color(0xFFFFFFFF)),
      PersonalColorSwatch('Navy', Color(0xFF132A4A)),
      PersonalColorSwatch('Burgundy', Color(0xFF781F35)),
      PersonalColorSwatch('Emerald', Color(0xFF006B54)),
    ],
    avoidColors: [
      PersonalColorSwatch('Be vàng', Color(0xFFE8D7A8)),
      PersonalColorSwatch('Cam pastel', Color(0xFFFFC09B)),
      PersonalColorSwatch('Vàng bơ', Color(0xFFFFE77A)),
      PersonalColorSwatch('Taupe bụi', Color(0xFFC3B2A3)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Satin',
        note: 'Bóng vừa, tăng độ sắc nét.',
        previewColors: [Color(0xFF111111), Color(0xFF781F35)],
      ),
      FabricSuggestion(
        name: 'Wool mịn',
        note: 'Đứng phom và sang.',
        previewColors: [Color(0xFF132A4A), Color(0xFF3D475B)],
      ),
      FabricSuggestion(
        name: 'Da bóng',
        note: 'Mạnh, hiện đại, hợp tương phản.',
        previewColors: [Color(0xFF0D0D0D), Color(0xFF2E2E2E)],
      ),
    ],
    wheelColors: [
      Color(0xFF111111),
      Color(0xFFFFFFFF),
      Color(0xFF132A4A),
      Color(0xFF781F35),
      Color(0xFF006B54),
    ],
  );

  static const brightWinter = PersonalColorProfile(
    id: 'bright_winter',
    title: 'Mùa Đông Rực Rỡ',
    subtitle: 'Sáng, lạnh và nổi bật',
    mainDescription:
        'Bạn chịu được màu rõ, tươi và có độ tương phản cao. Các gam cobalt, đỏ lạnh, fuchsia, trắng sáng và đen giúp tổng thể hiện đại, sắc sảo và rất nổi bật.',
    bestColorDescription:
        'Bảng màu hợp nhất gồm cobalt, fuchsia, đỏ cherry, xanh ngọc lạnh, trắng sáng và đen. Hãy chọn màu sạch, ít pha xám.',
    fabricDescription:
        'Các bề mặt gọn, rõ và có ánh nhẹ như satin, cotton đứng phom, da, denim đậm và vải kỹ thuật sẽ làm bảng màu rực lên đẹp nhất.',
    avoidDescription:
        'Tránh màu quá bùn, quá vàng hoặc quá mềm như olive xỉn, camel vàng, be tối và pastel bụi.',
    traits: ['Rực rỡ', 'Lạnh', 'Tương phản', 'Hiện đại'],
    bestColors: [
      PersonalColorSwatch('Cobalt', Color(0xFF0047AB)),
      PersonalColorSwatch('Fuchsia', Color(0xFFE91E63)),
      PersonalColorSwatch('Cherry', Color(0xFFD2042D)),
      PersonalColorSwatch('Ngọc lạnh', Color(0xFF00A6B4)),
      PersonalColorSwatch('Trắng', Color(0xFFFFFFFF)),
    ],
    avoidColors: [
      PersonalColorSwatch('Olive xỉn', Color(0xFF6B6A2D)),
      PersonalColorSwatch('Camel vàng', Color(0xFFC19762)),
      PersonalColorSwatch('Be tối', Color(0xFFBFA98A)),
      PersonalColorSwatch('Pastel bụi', Color(0xFFD4C3CB)),
    ],
    fabrics: [
      FabricSuggestion(
        name: 'Cotton đứng',
        note: 'Sạch, rõ và trẻ.',
        previewColors: [Color(0xFFFFFFFF), Color(0xFFE91E63)],
      ),
      FabricSuggestion(
        name: 'Satin lạnh',
        note: 'Tăng độ sáng cho màu nổi.',
        previewColors: [Color(0xFF0047AB), Color(0xFF00A6B4)],
      ),
      FabricSuggestion(
        name: 'Da/denim',
        note: 'Tạo tương phản mạnh mẽ.',
        previewColors: [Color(0xFF111111), Color(0xFF263C66)],
      ),
    ],
    wheelColors: [
      Color(0xFF0047AB),
      Color(0xFFE91E63),
      Color(0xFFD2042D),
      Color(0xFF00A6B4),
      Color(0xFFFFFFFF),
    ],
  );
}
