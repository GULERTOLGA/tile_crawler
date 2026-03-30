# tile_crawler

Harita karolarını (map tiles) belirli bir coğrafi kutu ve zoom aralığı için indirip diske yazan Flutter paketi. **XYZ (Slippy Map)** ve **WMTS** kaynaklarını destekler; çıktı dosya düzeni, `flutter_map` ve benzeri istemcilerle uyumlu olacak şekilde yapılandırılabilir.

**Sürüm:** 2.1.0  
**Dart:** `>=3.0.0 <4.0.0` · **Flutter:** `>=3.10.0`

[pub.dev](https://pub.dev/packages/tile_crawler) · [Kaynak kodu](https://github.com/GULERTOLGA/tile_crawler)

---

## Paket ne işe yarar?

Mobil veya masaüstü uygulamalarda haritayı **çevrimdışı** göstermek için önce karoları bir sunucudan indirip yerel bir klasöre kaydetmeniz gerekir. `tile_crawler` bu süreci yönetir:

- İndirilecek karoları **sınırlayıcı kutu (bounding box)** ve **min/max zoom** ile hesaplar.
- Her karo için **HTTP adresi** ve **diskte göreli yol** üretir (`ResolvedDownload`); yalnızca `{x},{y},{z}` şablonlarıyla sınırlı değildir; WMTS REST/KVP gibi şablonlar aynı akışa dahildir.
- **İçerik türüne** göre dosya uzantısını seçer (yanıt başlığı veya magic byte); her şeyi varsayılan `.png` olarak kaydetmez.
- **Önceden indirilmiş** dosyaları atlayarak gereksiz istekleri azaltır.
- İndirmeyi **iptal** etmeyi destekler.

Ağ erişimi **`dart:io` `HttpClient`** ile yapılır; `package:http` bağımlılığı yoktur. Ek olarak sadece `path` paketi kullanılır.

---

## Ana kavramlar

| Kavram | Açıklama |
|--------|-----------|
| `OfflineTileArchive` | Önerilen giriş noktası: `.xyz(...)` veya `.wmts(...)` ile indirme. |
| `StorageLayout` | Disk düzeni: Slippy XYZ (`z/x/y.ext`), TMS Y dönüşümü veya kaynağa özgü yol (`sourceRelativePath`). |
| `ResolvedDownload` | Tek karo için çözülmüş `Uri`, göreli dosya yolu ve ilerleme için `XYZ` anahtarı. |
| `TileDownloadService` | Düşük seviye: `downloadResolved` ile doğrudan plan besleme; isteğe bağlı `HttpClient` enjeksiyonu. |
| `TileDownloadSecurity` | İsteğe bağlı **host allow-list** (kullanıcı kontrolündeki URL şablonları için SSRF farkındalığı). |

Eski sınıflar `TileCrawler` ve `EnhancedTileCrawler` **kullanımdan kaldırılmıştır**; yeni projeler için `OfflineTileArchive` kullanın.

---

## Kurulum

```yaml
dependencies:
  tile_crawler: ^2.1.0
```

---

## Hızlı başlangıç (XYZ)

```dart
import 'package:tile_crawler/tile_crawler.dart';

final archive = OfflineTileArchive.xyz(
  topLeftLatLng: [40.7580, -73.9855],
  bottomRightLatLng: [40.7489, -73.9441],
  minZoomLevel: 10,
  maxZoomLevel: 12,
  tileUrlFormat: MapProviders.openStreetMap,
  downloadFolder: tilesDir, // Örn. path_provider ile uygulama dizini
);

await archive.download(
  onStart: (total, remaining, areaKm2) { /* ... */ },
  onProcess: (downloaded, remaining, xyz) { /* ... */ },
  onEnd: (totalDownloaded, totalSkipped) { /* ... */ },
  onProcessError: (xyz, error, stackTrace) { /* ... */ },
);
```

`MapProviders` içinde örnek URL şablonları vardır; kendi sunucunuzun `{z}/{x}/{y}` veya `{quadkey}` içeren şablonunu da verebilirsiniz.

---

## WMTS

```dart
final archive = OfflineTileArchive.wmts(
  topLeftLatLng: [/* ... */],
  bottomRightLatLng: [/* ... */],
  minZoomLevel: 10,
  maxZoomLevel: 12,
  urlTemplate: 'https://example.com/wmts/...',
  layer: '...',
  style: '...',
  tileMatrixSet: '...',
  format: 'png',
  useRestful: true,
  downloadFolder: tilesDir,
);
```

WMTS için varsayılan depolama düzeni `StorageLayout.sourceRelativePath` (katman/sunucu yapısına yakın yollar). **flutter_map** ile aynı Slippy ağacını (`z/x/y`) istiyorsanız `EnhancedDownloadOptions` / `OfflineTileArchive` oluştururken `storageLayout: StorageLayout.slippyMapXyz` verin. Ayrıntılar ve kırılan API notları için `CHANGELOG.md` (2.1.0) bölümüne bakın.

---

## Disk düzeni ve harita bileşenleri

| `StorageLayout` | Tipik kullanım |
|-------------------|----------------|
| `slippyMapXyz` | `kök/z/x/y.<ext>` — OSM/Google tarzı Slippy; **flutter_map** ile yerel dosya katmanlarında yaygın. |
| `tmsGlobalMercatorY` | TMS satır indeksi için Y ters çevirme ile aynı dosya şekli. |
| `sourceRelativePath` | `Tile.filePath` (ör. WMTS katman hiyerarşisi). |

**flutter_map:** İndirme kökünü katmanın dosya kökü olarak verin; şablon `{z}/{x}/{y}.png` (veya indirmede seçilen uzantı) ile uyumludur. Sürümünüze göre `FileTileProvider` veya dokümantasyondaki eşdeğeri kullanın.

---

## Güvenlik

- `safeTileFilePath`: Göreli yollarda `..` ve kök dışına çıkış engellenir.
- `TileDownloadSecurity`: İsteğe bağlı hostname allow-list.
- URL şablonları ve hedef sunucular uygulama mantığınıza bağlıdır; güvenilmeyen kullanıcı girdisi ile üretilen adreslerde SSRF riskini göz önünde bulundurun.

---

## İsteğe bağlı: yerel HTTP (`tile_crawler_server`)

Sadece HTTP URL kabul eden katmanlar için aynı monorepoda **`tile_crawler_server`** paketi bulunur: Slippy düzende yazılmış kökü yerel bir HTTP sunucusuyla sunar. Ana pakete transit bağımlılık eklenmez; ihtiyaç halinde ayrı eklenir.

---

## Örnek uygulama

```bash
cd example
flutter pub get
flutter run
```

Örnek, XYZ/WMTS indirme ekranları ve `flutter_map` ile yerel karoları kullanım içerir.

---

## Geliştirme

```bash
dart pub get
dart analyze lib test
flutter test
```

---

## Geçiş (1.x / 2.0 → 2.1)

- `OfflineTileArchive` kullanın.
- `TileCrawler.wmts` kaldırıldı; WMTS için `OfflineTileArchive.wmts(...)`.
- Tam liste: **`CHANGELOG.md`** (2.1.0).

---

## Lisans

[LICENCE](LICENSE) veya depodaki lisans dosyasına bakın.
