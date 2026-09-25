part of '../dashboard.dart';

extension _DashboardPlantController on _DashboardScreenState {
  Future<String?> _pickImageBase64() async {
      ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                const Text('Lampirkan Foto Tumbuhan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.camera_alt_rounded, color: Color(0xFF4A72EC))),
                    title: const Text('Ambil Foto (Kamera)', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.photo_library_rounded, color: Color(0xFF4A72EC))),
                    title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  
      if (source == null) return null;
  
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );
      if (image == null) return null;
  
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    }

  Future<void> _editPlant(SoilPlot plot) async {
      String newName = plot.name;
      String? newImageData = plot.imageData;
  
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Tanaman'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await _pickImageBase64();
                        if (picked != null) {
                          setDialogState(() => newImageData = picked);
                        }
                      },
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF4A72EC).withOpacity(0.25)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: newImageData != null
                            ? Image.memory(base64Decode(newImageData!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 36))
                            : const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4A72EC), size: 34),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      newImageData == null ? 'Tambah foto tanaman' : 'Ketuk foto untuk mengganti',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: plot.name,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => newName = value,
                      decoration: const InputDecoration(labelText: 'Nama tanaman', hintText: 'Contoh: Jeruk 1'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
                  ElevatedButton(onPressed: () { if (newName.trim().isNotEmpty) Navigator.pop(dialogContext, true); }, child: const Text('Simpan')),
                ],
              );
            },
          );
        },
      );
  
      if (result != true) return;
  
      final name = newName.trim();
      final user = FirebaseAuth.instance.currentUser;
  
      try {
        if (user == null) throw StateError('User belum login.');
  
        await _plantService.updatePlant(
          plantId: plot.id,
          name: name,
          imageData: newImageData,
        );
  
        if (!mounted) return;
        setState(() {
          plot.name = name;
          plot.imageData = newImageData;
        });
  
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanaman berhasil diperbarui.'), behavior: SnackBarBehavior.floating));
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah tanaman: ${e.code}'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah tanaman: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    }

  Future<void> _deletePlant(SoilPlot plot) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Hapus Tanaman?'),
            content: Text(
              'Tanaman "${plot.name}" beserta seluruh riwayat pengukurannya akan dihapus dari database.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hapus'),
              ),
            ],
          );
        },
      );
  
      if (confirmed != true) return;
  
      final user = FirebaseAuth.instance.currentUser;
  
      try {
        if (user == null) {
          throw StateError('User belum login.');
        }
  
        await _plantService.deletePlant(plot.id);
  
        // Data lokal yang masih menunggu sinkronisasi tidak boleh ikut kembali
        // menghidupkan data tanaman yang sudah dihapus.
        try {
          await _measurementService.deletePendingRecordsForPlant(plot.id);
        } catch (_) {
          // Penghapusan Firestore tetap dianggap berhasil meskipun pembersihan
          // cache lokal gagal.
        }
  
        if (!mounted) return;
        setState(() {
          final deletedIndex = plots.indexOf(plot);
          plots.remove(plot);
  
          if (plots.isEmpty) {
            selectedPlotIndex = 0;
          } else if (selectedPlotIndex > deletedIndex) {
            selectedPlotIndex--;
          } else if (selectedPlotIndex >= plots.length) {
            selectedPlotIndex = plots.length - 1;
          }
        });
  
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanaman berhasil dihapus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tanaman: ${e.code}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tanaman: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  
    // Bottom Sheet Memilih / Menambah Tanaman

  void _showPlotManagerSheet() {
      String newPlotName = '';
      String? newPlotImage;
      bool isAddingPlant = false;
  
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
  
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(bottom: keyboardBottom),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.78,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pilih Tanaman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.30,
                          child: isLoadingPlants
                              ? const Center(child: CircularProgressIndicator())
                              : plots.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.eco_outlined,
                                            size: 46,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Belum ada tanaman',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tambahkan tanaman untuk mulai mengukur.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                  itemCount: plots.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final p = plots[index];
                                    final isCurrent = selectedPlotIndex == index;
  
                                    return Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      child: ListTile(
                                        tileColor: isCurrent
                                            ? const Color(0xFF4A72EC).withOpacity(0.08)
                                            : Colors.grey.shade50,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          side: BorderSide(
                                            color: isCurrent
                                                ? const Color(0xFF4A72EC)
                                                : Colors.transparent,
                                            width: 1.2,
                                          ),
                                        ),
                                        leading: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: const Color(0xFF4A72EC).withOpacity(0.1),
                                          ),
                                          child: p.imageData != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.memory(
                                                    base64Decode(p.imageData!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: Color(0xFF4A72EC)),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.eco_rounded,
                                                  color: Color(0xFF4A72EC),
                                                ),
                                        ),
                                        title: Text(
                                          p.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent
                                                ? const Color(0xFF4A72EC)
                                                : primaryTextColor,
                                          ),
                                        ),
                                        subtitle: Text('${p.records.length} data tersimpan'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCurrent)
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                color: Color(0xFF4A72EC),
                                              ),
                                            PopupMenuButton<String>(
                                              tooltip: 'Kelola tanaman',
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  _editPlant(p);
                                                } else if (value == 'delete') {
                                                  _deletePlant(p);
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit_rounded, size: 19),
                                                      SizedBox(width: 10),
                                                      Text('Edit nama'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                                                      SizedBox(width: 10),
                                                      Text('Hapus'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          setState(() => selectedPlotIndex = index);
                                          Navigator.pop(sheetContext);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (imageContext, setImageState) {
                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await _pickImageBase64();
                                    if (picked != null) {
                                      newPlotImage = picked;
                                      setImageState(() {});
                                    }
                                  },
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: newPlotImage != null
                                        ? Image.memory(base64Decode(newPlotImage!), fit: BoxFit.cover)
                                        : const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4A72EC)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    newPlotImage == null ? 'Tambah foto tanaman (opsional)' : 'Foto tanaman dipilih',
                                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (value) => newPlotName = value,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: 'Nama tanaman (mis: Jeruk ${plots.length + 1})',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: isAddingPlant
                                  ? null
                                  : () async {
                                      final text = newPlotName.trim();
                                      if (text.isEmpty) return;
  
                                      setSheetState(() => isAddingPlant = true);
  
                                      try {
                                        final doc = await _plantService.addPlant(
                                          name: text,
                                          imageData: newPlotImage,
                                        );
  
                                        if (!mounted) return;
  
                                        setState(() {
                                          plots.add(
                                            SoilPlot(
                                              id: doc.id,
                                              name: text,
                                              imageData: newPlotImage,
                                              records: [],
                                            ),
                                          );
                                          selectedPlotIndex = plots.length - 1;
                                        });
  
                                        if (Navigator.canPop(sheetContext)) {
                                          Navigator.pop(sheetContext);
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          setSheetState(() => isAddingPlant = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Gagal menambahkan tanah ke database.'),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isAddingPlant
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Tambah',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
}
