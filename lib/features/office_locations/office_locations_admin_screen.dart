import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:pulseclock/features/attendance/location/office_location_service.dart';
import 'package:pulseclock/features/auth/data/auth_service.dart';
import 'package:pulseclock/pulseclock/styles.dart';
import 'package:pulseclock/pulseclock/widgets/pulse_clock_widgets.dart';

const double _minimumOfficeRadiusMeters = 80;
const double _maximumOfficeRadiusMeters = 500;
const int _maximumOfficeNameLength = 60;
const String _coordinatePattern = r'^-?\d{1,3}(\.\d{1,8})?$';
const Map<String, List<String>> _zambiaDistrictsByProvince =
    <String, List<String>>{
      'Central': <String>[
        'Chibombo',
        'Chisamba',
        'Chitambo',
        'Itezhi-Tezhi',
        'Kabwe',
        'Kapiri Mposhi',
        'Luano',
        'Mkushi',
        'Mumbwa',
        'Ngabwe',
        'Serenje',
        'Shibuyunji',
      ],
      'Copperbelt': <String>[
        'Chililabombwe',
        'Chingola',
        'Kalulushi',
        'Kitwe',
        'Luanshya',
        'Lufwanyama',
        'Masaiti',
        'Mpongwe',
        'Mufulira',
        'Ndola',
      ],
      'Eastern': <String>[
        'Chadiza',
        'Chasefu',
        'Chipangali',
        'Chipata',
        'Kasenengwa',
        'Katete',
        'Lumezi',
        'Lundazi',
        'Lusangazi',
        'Mambwe',
        'Nyimba',
        'Petauke',
        'Sinda',
        'Vubwi',
      ],
      'Luapula': <String>[
        'Chembe',
        'Chienge',
        'Chifunabuli',
        'Chipili',
        'Kawambwa',
        'Lunga',
        'Mansa',
        'Milenge',
        'Mwansabombwe',
        'Mwense',
        'Nchelenge',
        'Samfya',
      ],
      'Lusaka': <String>[
        'Chilanga',
        'Chirundu',
        'Chongwe',
        'Kafue',
        'Luangwa',
        'Lusaka',
        'Rufunsa',
      ],
      'Muchinga': <String>[
        'Chama',
        'Chinsali',
        'Isoka',
        'Kanchibiya',
        'Lavushimanda',
        'Mafinga',
        'Mpika',
        'Nakonde',
        "Shiwang'andu",
      ],
      'Northern': <String>[
        'Chilubi',
        'Kaputa',
        'Kasama',
        'Lunte',
        'Lupososhi',
        'Luwingu',
        'Mbala',
        'Mporokoso',
        'Mpulungu',
        'Nsama',
        'Senga Hill',
      ],
      'North-Western': <String>[
        'Chavuma',
        "Ikeleng'i",
        'Kabompo',
        'Kalumbila',
        'Kasempa',
        'Manyinga',
        'Mufumbwe',
        'Mushindamo',
        'Mwinilunga',
        'Solwezi',
        'Zambezi',
      ],
      'Southern': <String>[
        'Chikankata',
        'Choma',
        'Chirundu',
        'Gwembe',
        'Itezhi-Tezhi',
        'Kalomo',
        'Kazungula',
        'Livingstone',
        'Mazabuka',
        'Monze',
        'Namwala',
        'Pemba',
        'Siavonga',
        'Sinazongwe',
        'Zimba',
      ],
      'Western': <String>[
        'Kalabo',
        'Kaoma',
        'Limulunga',
        'Luampa',
        'Lukulu',
        'Mitete',
        'Mongu',
        'Mulobezi',
        'Mwandi',
        'Nalolo',
        'Nkeyema',
        'Senanga',
        'Sesheke',
        'Shangombo',
        'Sikongo',
        'Sioma',
      ],
    };

class OfficeLocationsAdminScreen extends StatefulWidget {
  const OfficeLocationsAdminScreen({super.key});

  @override
  State<OfficeLocationsAdminScreen> createState() =>
      _OfficeLocationsAdminScreenState();
}

class _OfficeLocationsAdminScreenState
    extends State<OfficeLocationsAdminScreen> {
  static const Set<String> _managerRoles = <String>{
    'supervisor',
    'hr',
    'admin',
  };

  final OfficeLocationService _officeLocationService = OfficeLocationService();

  bool _isLoading = true;
  String? _errorMessage;
  List<OfficeLocation> _officeLocations = const <OfficeLocation>[];

  @override
  void initState() {
    super.initState();
    _loadOfficeLocations();
  }

  Future<void> _loadOfficeLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!SupabaseBootstrap.isInitialized) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Supabase is not connected for this run. Office locations need the backend.';
      });
      return;
    }

    try {
      final WorkPulseUserProfile? profile = await AuthService()
          .fetchCurrentProfile();
      if (profile == null || !_managerRoles.contains(profile.role)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Only supervisors, HR, and admins can manage office locations.';
        });
        return;
      }

      final List<OfficeLocation> locations = await _officeLocationService
          .fetchOfficeLocations();
      if (!mounted) {
        return;
      }
      setState(() {
        _officeLocations = locations;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load office locations right now.';
      });
    }
  }

  Future<void> _openForm({OfficeLocation? officeLocation}) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => OfficeLocationFormScreen(officeLocation: officeLocation),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (saved == true) {
      await _loadOfficeLocations();
    }
  }

  Future<void> _toggleOfficeStatus(OfficeLocation officeLocation) async {
    if (officeLocation.isActive) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFCFDFE),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              'Deactivate Office?',
              style: PulseClockTextStyles.cardTitle.copyWith(fontSize: 20),
            ),
            content: Text(
              '${officeLocation.officeName} will stop being used for geofence verification until it is activated again.',
              style: PulseClockTextStyles.cardSubtitle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Deactivate'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    try {
      final OfficeLocation updated = await _officeLocationService
          .setOfficeActive(
            id: officeLocation.id,
            isActive: !officeLocation.isActive,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _officeLocations = _officeLocations
            .map(
              (OfficeLocation item) => item.id == updated.id ? updated : item,
            )
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isActive
                ? '${updated.officeName} is active.'
                : '${updated.officeName} is inactive.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update office status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: const Text('Office Locations'),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              20,
              PulseClockDimensions.horizontalPadding,
              24,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            PulseClockColors.onBackgroundPrimary,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SurfaceCard(
          child: Text(
            _errorMessage!,
            style: PulseClockTextStyles.cardSubtitle.copyWith(
              color: PulseClockColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage approved WorkPulse offices for geofence verification.',
          style: PulseClockTextStyles.headerSubtitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_location_alt_outlined, size: 20),
            label: const Text('Add Office Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PulseClockColors.actionBlue,
              foregroundColor: PulseClockColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: PulseClockTextStyles.contextAction.copyWith(
                color: PulseClockColors.surface,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  PulseClockDimensions.cardRadius,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOfficeLocations,
            child: _officeLocations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 160),
                      _EmptyOfficeLocationsCard(),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      final OfficeLocation officeLocation =
                          _officeLocations[index];
                      return _OfficeLocationCard(
                        officeLocation: officeLocation,
                        onEdit: () => _openForm(officeLocation: officeLocation),
                        onToggleStatus: () =>
                            _toggleOfficeStatus(officeLocation),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemCount: _officeLocations.length,
                  ),
          ),
        ),
      ],
    );
  }
}

class OfficeLocationFormScreen extends StatefulWidget {
  const OfficeLocationFormScreen({super.key, this.officeLocation});

  final OfficeLocation? officeLocation;

  @override
  State<OfficeLocationFormScreen> createState() =>
      _OfficeLocationFormScreenState();
}

class _OfficeLocationFormScreenState extends State<OfficeLocationFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final OfficeLocationService _officeLocationService = OfficeLocationService();
  final TextEditingController _officeNameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(
    text: '100',
  );

  bool _isSaving = false;
  bool _isCapturing = false;
  double? _capturedAccuracyMeters;
  String? _selectedProvince;
  String? _selectedDistrict;

  bool get _isEditing => widget.officeLocation != null;
  List<String> get _availableDistricts =>
      _zambiaDistrictsByProvince[_selectedProvince] ?? const <String>[];

  @override
  void initState() {
    super.initState();
    final OfficeLocation? officeLocation = widget.officeLocation;
    if (officeLocation != null) {
      _officeNameController.text = officeLocation.officeName;
      if (_zambiaDistrictsByProvince.containsKey(officeLocation.province)) {
        _selectedProvince = officeLocation.province;
      }
      if (_availableDistricts.contains(officeLocation.district)) {
        _selectedDistrict = officeLocation.district;
      }
      _latitudeController.text = officeLocation.latitude.toStringAsFixed(6);
      _longitudeController.text = officeLocation.longitude.toStringAsFixed(6);
      _radiusController.text = officeLocation.radiusMeters.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _officeNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _captureCurrentGps() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Turn on location services, then try again.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission was not granted.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          'Location permission is blocked. Enable it in Android settings.',
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _capturedAccuracyMeters = position.accuracy;
      });
    } catch (_) {
      _showSnackBar('Unable to capture current GPS.');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _saveOfficeLocation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final String officeName = _officeNameController.text.trim();
    final String province = _selectedProvince!;
    final String district = _selectedDistrict!;
    final double latitude = double.parse(_latitudeController.text.trim());
    final double longitude = double.parse(_longitudeController.text.trim());
    final double radiusMeters = double.parse(_radiusController.text.trim());

    try {
      final OfficeLocation? existingLocation = widget.officeLocation;
      if (existingLocation == null) {
        await _officeLocationService.createOfficeLocation(
          officeName: officeName,
          province: province,
          district: district,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        );
      } else {
        await _officeLocationService.updateOfficeLocation(
          id: existingLocation.id,
          officeName: officeName,
          province: province,
          district: district,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          isActive: existingLocation.isActive,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingLocation == null
                ? 'Office location created.'
                : 'Office location updated.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Unable to save office location. Check for duplicate office names or permissions.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PulseClockColors.surface,
        foregroundColor: PulseClockColors.textPrimary,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Office Location' : 'Add Office Location',
        ),
      ),
      backgroundColor: PulseClockColors.appBackgroundSolid,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseClockColors.appBackground,
              PulseClockColors.appBackgroundDeep,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              PulseClockDimensions.horizontalPadding,
              20,
              PulseClockDimensions.horizontalPadding,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: _formKey,
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Office Details',
                      style: PulseClockTextStyles.cardTitle.copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AdminTextField(
                      controller: _officeNameController,
                      label: 'Office Name',
                      textInputAction: TextInputAction.next,
                      maxLength: _maximumOfficeNameLength,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[A-Za-z0-9 .,&'()/-]"),
                        ),
                      ],
                      validator: (String? value) {
                        final String officeName = value?.trim() ?? '';
                        if (officeName.isEmpty) {
                          return 'Enter an office name.';
                        }
                        if (officeName.length < 3) {
                          return 'Use at least 3 characters.';
                        }
                        if (officeName.length > _maximumOfficeNameLength) {
                          return 'Use $_maximumOfficeNameLength characters or fewer.';
                        }
                        if (!RegExp(
                          r"^[A-Za-z0-9][A-Za-z0-9 .,&'()/-]*$",
                        ).hasMatch(officeName)) {
                          return 'Use letters, numbers, spaces, and simple punctuation only.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _AdminDropdownField(
                      label: 'Province',
                      value: _selectedProvince,
                      items: _zambiaDistrictsByProvince.keys.toList(),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Select province.';
                        }
                        return null;
                      },
                      onChanged: (String? value) {
                        setState(() {
                          _selectedProvince = value;
                          _selectedDistrict = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _AdminDropdownField(
                      label: 'District',
                      value: _selectedDistrict,
                      items: _availableDistricts,
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Select district.';
                        }
                        return null;
                      },
                      onChanged: _selectedProvince == null
                          ? null
                          : (String? value) {
                              setState(() {
                                _selectedDistrict = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCapturing ? null : _captureCurrentGps,
                        icon: _isCapturing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PulseClockColors.actionBlue,
                                  ),
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          _isCapturing
                              ? 'Capturing Current GPS'
                              : 'Capture Current GPS',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PulseClockColors.actionBlue,
                          side: const BorderSide(
                            color: PulseClockColors.actionBlue,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          textStyle: PulseClockTextStyles.contextAction
                              .copyWith(fontSize: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    if (_capturedAccuracyMeters != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Captured accuracy: ${_capturedAccuracyMeters!.toStringAsFixed(1)} m',
                        style: PulseClockTextStyles.cardSubtitle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminTextField(
                            controller: _latitudeController,
                            label: 'Latitude',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            textInputAction: TextInputAction.next,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[-0-9.]'),
                              ),
                              LengthLimitingTextInputFormatter(12),
                            ],
                            validator: (String? value) =>
                                _validateCoordinate(value, min: -90, max: 90),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AdminTextField(
                            controller: _longitudeController,
                            label: 'Longitude',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            textInputAction: TextInputAction.next,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[-0-9.]'),
                              ),
                              LengthLimitingTextInputFormatter(13),
                            ],
                            validator: (String? value) =>
                                _validateCoordinate(value, min: -180, max: 180),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AdminTextField(
                      controller: _radiusController,
                      label: 'Allowed Radius (metres)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: _validateRadius,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveOfficeLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseClockColors.actionBlue,
                          foregroundColor: PulseClockColors.surface,
                          disabledBackgroundColor: PulseClockColors.actionBlue
                              .withValues(alpha: 0.45),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: PulseClockTextStyles.contextAction
                              .copyWith(
                                color: PulseClockColors.surface,
                                fontSize: 16,
                              ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PulseClockDimensions.cardRadius,
                            ),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PulseClockColors.surface,
                                  ),
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Save Office Location'
                                    : 'Create Office Location',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateCoordinate(
    String? value, {
    required double min,
    required double max,
  }) {
    final String rawValue = value ?? '';
    final String trimmedValue = rawValue.trim();
    if (trimmedValue.isEmpty) {
      return 'Required';
    }
    if (rawValue != trimmedValue ||
        !RegExp(_coordinatePattern).hasMatch(trimmedValue)) {
      return 'Invalid format';
    }
    final double? coordinate = double.tryParse(trimmedValue);
    if (coordinate == null) {
      return 'Required';
    }
    if (coordinate < min || coordinate > max) {
      return 'Invalid';
    }
    return null;
  }

  String? _validateRadius(String? value) {
    final String rawValue = value ?? '';
    final String trimmedValue = rawValue.trim();
    if (trimmedValue.isEmpty || rawValue != trimmedValue) {
      return 'Enter radius.';
    }
    if (!RegExp(r'^\d{1,3}$').hasMatch(trimmedValue)) {
      return 'Use numbers only.';
    }
    final double? radius = double.tryParse(trimmedValue);
    if (radius == null) {
      return 'Enter radius.';
    }
    if (radius < _minimumOfficeRadiusMeters) {
      return 'Minimum radius is ${_minimumOfficeRadiusMeters.toStringAsFixed(0)} m.';
    }
    if (radius > _maximumOfficeRadiusMeters) {
      return 'Maximum radius is ${_maximumOfficeRadiusMeters.toStringAsFixed(0)} m.';
    }
    return null;
  }
}

class _OfficeLocationCard extends StatelessWidget {
  const _OfficeLocationCard({
    required this.officeLocation,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final OfficeLocation officeLocation;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = officeLocation.isActive
        ? const Color(0xFF0F8A43)
        : PulseClockColors.textSecondary;
    final Color statusBackground = officeLocation.isActive
        ? const Color(0x1415803D)
        : PulseClockColors.surfaceMuted;
    final String? district = officeLocation.district?.isNotEmpty == true
        ? officeLocation.district
        : null;
    final String? province = officeLocation.province?.isNotEmpty == true
        ? officeLocation.province
        : null;
    final String districtProvince = district != null && province != null
        ? '$district District, $province'
        : district ?? province ?? '';

    return Material(
      color: PulseClockColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PulseClockColors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            officeLocation.officeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: PulseClockColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            officeLocation.isActive ? 'Active' : 'Inactive',
                            style: PulseClockTextStyles.cardSubtitle.copyWith(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      districtProvince.isEmpty
                          ? 'Location area not set'
                          : districtProvince,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${officeLocation.radiusMeters.toStringAsFixed(0)} m radius | '
                      '${officeLocation.latitude.toStringAsFixed(5)}, ${officeLocation.longitude.toStringAsFixed(5)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseClockTextStyles.cardSubtitle.copyWith(
                        fontSize: 11,
                        color: PulseClockColors.textSecondary.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Office actions',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: PulseClockColors.textSecondary,
                ),
                onSelected: (String value) {
                  if (value == 'edit') {
                    onEdit();
                    return;
                  }
                  if (value == 'toggle') {
                    onToggleStatus();
                  }
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Text(
                        officeLocation.isActive ? 'Deactivate' : 'Activate',
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator: validator,
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: PulseClockColors.surfaceMuted,
        labelStyle: PulseClockTextStyles.cardSubtitle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: PulseClockColors.actionBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _AdminDropdownField extends StatelessWidget {
  const _AdminDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map(
            (String item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      style: PulseClockTextStyles.cardSubtitle.copyWith(
        color: PulseClockColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: PulseClockColors.surfaceMuted,
        labelStyle: PulseClockTextStyles.cardSubtitle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PulseClockColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: PulseClockColors.actionBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _EmptyOfficeLocationsCard extends StatelessWidget {
  const _EmptyOfficeLocationsCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.location_off_outlined,
            color: PulseClockColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No office locations found.',
              style: PulseClockTextStyles.cardSubtitle.copyWith(
                color: PulseClockColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
