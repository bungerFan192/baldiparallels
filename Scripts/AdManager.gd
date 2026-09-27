
extends Node2D

@onready var admob: Admob = $Admob

signal rewarded_keep_score_granted
signal rewarded_closed_without_reward
signal rewarded_ready
signal rewarded_failed

signal interstitial_ready
signal interstitial_failed
signal interstitial_closed

signal fullscreen_ad_started
signal fullscreen_ad_closed

var is_initialized: = false

var rewarded_loaded: = false
var rewarded_loading: = false
var rewarded_fail_count: = 0
const REWARDED_FAIL_THRESHOLD: = 3

var interstitial_loaded: = false
var interstitial_loading: = false
var interstitial_fail_count: = 0
const INTERSTITIAL_FAIL_THRESHOLD: = 3

var _reward_earned_this_show: = false

const LOG_PREFIX: = "[ADS] "

var _show_consent_after_load: = false
var _consent_flow_completed: = false
var _privacy_options_applicable: = false
var _consent_update_fail_count: = 0
var _consent_retry_pending: = false
const CONSENT_UPDATE_FAIL_THRESHOLD: = 3
const CONSENT_RETRY_BASE_DELAY: = 1.5

var rewarded_showing: = false
var fullscreen_ad_showing: = false


func _begin_fullscreen_ad() -> void :
	if fullscreen_ad_showing:
		return
	fullscreen_ad_showing = true
	fullscreen_ad_started.emit()


func _end_fullscreen_ad() -> void :
	if not fullscreen_ad_showing:
		return
	fullscreen_ad_showing = false
	fullscreen_ad_closed.emit()

func _ready() -> void :
	_log("Node ready")

	if admob == null:
		push_error(LOG_PREFIX + "Admob node not found at $Admob")
		return

	_log("Admob node found: %s" % admob)

	_connect_signal_if_needed(admob.initialization_completed, _on_admob_initialization_completed, "initialization_completed")


	_connect_signal_if_needed(admob.consent_info_updated, _on_consent_info_updated, "consent_info_updated")
	_connect_signal_if_needed(admob.consent_info_update_failed, _on_consent_info_update_failed, "consent_info_update_failed")
	_connect_signal_if_needed(admob.consent_form_loaded, _on_consent_form_loaded, "consent_form_loaded")
	_connect_signal_if_needed(admob.consent_form_failed_to_load, _on_consent_form_failed_to_load, "consent_form_failed_to_load")
	_connect_signal_if_needed(admob.consent_form_dismissed, _on_consent_form_dismissed, "consent_form_dismissed")

	_connect_signal_if_needed(admob.rewarded_ad_loaded, _on_admob_rewarded_ad_loaded, "rewarded_ad_loaded")
	_connect_signal_if_needed(admob.rewarded_ad_failed_to_load, _on_admob_rewarded_ad_failed_to_load, "rewarded_ad_failed_to_load")
	_connect_signal_if_needed(admob.rewarded_ad_failed_to_show_full_screen_content, _on_admob_rewarded_ad_failed_to_show_full_screen_content, "rewarded_ad_failed_to_show_full_screen_content")
	_connect_signal_if_needed(admob.rewarded_ad_dismissed_full_screen_content, _on_admob_rewarded_ad_dismissed_full_screen_content, "rewarded_ad_dismissed_full_screen_content")
	_connect_signal_if_needed(admob.rewarded_ad_user_earned_reward, _on_admob_rewarded_ad_user_earned_reward, "rewarded_ad_user_earned_reward")

	_connect_signal_if_needed(admob.interstitial_ad_loaded, _on_admob_interstitial_ad_loaded, "interstitial_ad_loaded")
	_connect_signal_if_needed(admob.interstitial_ad_failed_to_load, _on_admob_interstitial_ad_failed_to_load, "interstitial_ad_failed_to_load")
	_connect_signal_if_needed(admob.interstitial_ad_failed_to_show_full_screen_content, _on_admob_interstitial_ad_failed_to_show_full_screen_content, "interstitial_ad_failed_to_show_full_screen_content")
	_connect_signal_if_needed(admob.interstitial_ad_dismissed_full_screen_content, _on_admob_interstitial_ad_dismissed_full_screen_content, "interstitial_ad_dismissed_full_screen_content")




	_log("Calling admob.initialize() first")
	admob.initialize()

func is_privacy_options_available() -> bool:
	return _privacy_options_applicable

func _on_admob_initialization_completed(status_data: InitializationStatus) -> void :
	is_initialized = true
	_log("AdMob initialization completed")
	_log_obj("Initialization status", status_data)

	_log("Requesting consent info update...")
	admob.update_consent_info()

func _log_consent_status() -> void :
	var user_consent: = admob.get_consent_status()
	if user_consent == null:
		_log("get_consent_status() returned null")
		return
	_log("consent status: %d (%s)" % [user_consent.status, user_consent.to_status_string()])
	_log("is_consent_form_available: %s" % str(admob.is_consent_form_available()))

signal consent_status_known(privacy_options_applicable: bool)

func _on_consent_info_updated() -> void :
	_consent_update_fail_count = 0
	_consent_retry_pending = false
	_log_consent_status()
	var user_consent: = admob.get_consent_status()
	var status: = user_consent.status if user_consent != null else 0




	_privacy_options_applicable = status == 2 or status == 3
	emit_signal("consent_status_known", _privacy_options_applicable)

	if status == 1 or status == 3:
		_log("Consent already handled (status %d), loading ads..." % status)
		_consent_flow_completed = true
		_start_loading_ads()
		return

	if status == 2:
		_log("Consent required, loading form regardless of cached availability...")
		_show_consent_after_load = true
		admob.load_consent_form()
		return

	_log("Consent status is UNKNOWN; fullscreen ads remain unloaded")

func _on_consent_info_update_failed(error_data: FormError) -> void :
	_consent_update_fail_count += 1
	_log("consent_info_update_failed")
	_log_obj("consent update error", error_data)
	_log_consent_status()
	_privacy_options_applicable = false
	emit_signal("consent_status_known", false)

	if _consent_update_fail_count < CONSENT_UPDATE_FAIL_THRESHOLD:
		_schedule_consent_info_retry()
	else:
		_log(
			"Consent update retry threshold reached; fullscreen ads remain "
			+ "unloaded while consent status is UNKNOWN"
		)


func _schedule_consent_info_retry() -> void :
	if _consent_retry_pending:
		return
	_consent_retry_pending = true
	var retry_number: = _consent_update_fail_count
	var retry_delay: = CONSENT_RETRY_BASE_DELAY * float(retry_number)
	_log(
		"Retrying consent info update in %.1f seconds (%d/%d)"
		%[retry_delay, retry_number + 1, CONSENT_UPDATE_FAIL_THRESHOLD]
	)
	await get_tree().create_timer(retry_delay).timeout
	_consent_retry_pending = false
	if _consent_flow_completed:
		return
	_log("Requesting consent info update retry...")
	admob.update_consent_info()


func _on_consent_form_failed_to_load(error_data: FormError) -> void :
	_log("consent_form_failed_to_load")
	_log_obj("consent form load error", error_data)
	_log_consent_status()
	_log("Consent form was not shown; fullscreen ads remain unloaded")


func _start_loading_ads() -> void :
	if not is_initialized:
		_log("_start_loading_ads() ignored: plugin not initialized")
		return

	load_rewarded()
	load_interstitial()


var _consent_form_ready: = false


func _on_consent_form_loaded() -> void :
	_log("Consent form loaded")
	_consent_form_ready = true
	if _show_consent_after_load:
		_show_consent_after_load = false
		_log("Showing consent form...")
		_consent_form_ready = false
		admob.show_consent_form()


func _on_consent_form_dismissed(error_data: FormError) -> void :
	_log("consent_form_dismissed")
	_log_consent_status()
	_consent_form_ready = false


	admob.load_consent_form()

	if not _consent_flow_completed:
		_consent_flow_completed = true
		_start_loading_ads()


func show_privacy_options() -> void :
	if not _privacy_options_applicable:
		_log("show_privacy_options() ignored: privacy options do not apply")
		return

	if _consent_form_ready:
		_log("Showing cached privacy options form")
		_consent_form_ready = false
		admob.show_consent_form()
	else:
		_log("Form not cached yet, loading first...")
		_show_consent_after_load = true
		admob.load_consent_form()


func _connect_signal_if_needed(signal_obj: Signal, callable: Callable, label: String) -> void :
	if not signal_obj.is_connected(callable):
		signal_obj.connect(callable)
		_log("Connected signal: %s" % label)

func _log(msg: String) -> void :
	print(LOG_PREFIX + msg)

func _log_obj(label: String, obj) -> void :
	if obj == null:
		print("%s%s: null" % [LOG_PREFIX, label])
		return

	var props: = []
	for p in obj.get_property_list():
		var name = str(p.name)
		if name in ["script", "resource_local_to_scene", "resource_path", "resource_name"]:
			continue
		props.append("%s=%s" % [name, str(obj.get(name))])

	print("%s%s: %s" % [LOG_PREFIX, label, ", ".join(props)])






func load_rewarded() -> void :
	if not is_initialized:
		_log("load_rewarded() ignored: not initialized")
		return
	if rewarded_loaded:
		_log("load_rewarded() ignored: already loaded")
		return
	if rewarded_loading:
		_log("load_rewarded() ignored: already loading")
		return

	rewarded_loading = true
	_log("Requesting rewarded ad...")
	admob.load_rewarded_ad()


func show_rewarded_if_ready() -> bool:
	_log("show_rewarded_if_ready() loaded=%s loading=%s" % [str(rewarded_loaded), str(rewarded_loading)])

	if not is_initialized:
		_log("Rewarded not shown: AdMob not initialized")
		return false

	if rewarded_loaded:
		_reward_earned_this_show = false
		rewarded_loaded = false
		rewarded_showing = true
		_log("Showing rewarded ad")
		_begin_fullscreen_ad()
		admob.show_rewarded_ad()
		return true

	_log("Rewarded ad not ready yet, requesting load")
	load_rewarded()
	return false


func _on_admob_rewarded_ad_loaded(ad_info: AdInfo, response_info: ResponseInfo) -> void :
	rewarded_loaded = true
	rewarded_loading = false
	rewarded_fail_count = 0

	_log("rewarded_ad_loaded")
	_log_obj("rewarded ad_info", ad_info)
	_log_obj("rewarded response_info", response_info)
	emit_signal("rewarded_ready")


func _on_admob_rewarded_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError) -> void :
	rewarded_loaded = false
	rewarded_loading = false
	rewarded_fail_count += 1

	_log("rewarded_ad_failed_to_load")
	_log_obj("rewarded ad_info", ad_info)
	_log_obj("rewarded error_data", error_data)

	if rewarded_fail_count < REWARDED_FAIL_THRESHOLD:
		_log("Retrying rewarded load")
		load_rewarded()
	else:
		_log("Rewarded retry threshold reached")
		emit_signal("rewarded_failed")


func _on_admob_rewarded_ad_failed_to_show_full_screen_content(ad_info: AdInfo, error_data: AdError) -> void :
	rewarded_showing = false
	rewarded_loaded = false
	rewarded_loading = false
	rewarded_fail_count += 1

	_log("rewarded_ad_failed_to_show_full_screen_content")
	_log_obj("rewarded ad_info", ad_info)
	_log_obj("rewarded error_data", error_data)

	emit_signal("rewarded_closed_without_reward")
	_end_fullscreen_ad()

	if rewarded_fail_count < REWARDED_FAIL_THRESHOLD:
		load_rewarded()


func _on_admob_rewarded_ad_dismissed_full_screen_content(ad_info: AdInfo) -> void :
	rewarded_showing = false
	rewarded_loaded = false
	rewarded_loading = false

	if not _reward_earned_this_show:
		emit_signal("rewarded_closed_without_reward")
	_end_fullscreen_ad()

	_reward_earned_this_show = false
	rewarded_fail_count = 0
	load_rewarded()


func _on_admob_rewarded_ad_user_earned_reward(ad_info: AdInfo, reward_data: RewardItem) -> void :
	_reward_earned_this_show = true

	_log("rewarded_ad_user_earned_reward")
	_log_obj("rewarded ad_info", ad_info)
	_log_obj("rewarded reward_data", reward_data)

	emit_signal("rewarded_keep_score_granted")






func load_interstitial() -> void :
	if not is_initialized:
		_log("load_interstitial() ignored: not initialized")
		return
	if interstitial_loaded:
		_log("load_interstitial() ignored: already loaded")
		return
	if interstitial_loading:
		_log("load_interstitial() ignored: already loading")
		return

	interstitial_loading = true
	_log("Requesting interstitial ad...")
	admob.load_interstitial_ad()


func show_interstitial_if_ready() -> bool:
	_log("show_interstitial_if_ready() loaded=%s loading=%s" % [str(interstitial_loaded), str(interstitial_loading)])

	if not is_initialized:
		_log("Interstitial not shown: AdMob not initialized")
		return false

	if interstitial_loaded:
		interstitial_loaded = false
		_log("Showing interstitial ad")
		_begin_fullscreen_ad()
		admob.show_interstitial_ad()
		return true

	_log("Interstitial not ready yet, requesting load")
	load_interstitial()
	return false


func _on_admob_interstitial_ad_loaded(ad_info: AdInfo, response_info: ResponseInfo) -> void :
	interstitial_loaded = true
	interstitial_loading = false
	interstitial_fail_count = 0

	_log("interstitial_ad_loaded")
	_log_obj("interstitial ad_info", ad_info)
	_log_obj("interstitial response_info", response_info)

	emit_signal("interstitial_ready")


func _on_admob_interstitial_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError) -> void :
	interstitial_loaded = false
	interstitial_loading = false
	interstitial_fail_count += 1

	_log("interstitial_ad_failed_to_load")
	_log_obj("interstitial ad_info", ad_info)
	_log_obj("interstitial error_data", error_data)

	emit_signal("interstitial_failed")

	if interstitial_fail_count < INTERSTITIAL_FAIL_THRESHOLD:
		_log("Retrying interstitial load")
		load_interstitial()
	else:
		_log("Interstitial retry threshold reached")


func _on_admob_interstitial_ad_failed_to_show_full_screen_content(ad_info: AdInfo, error_data: AdError) -> void :
	interstitial_loaded = false
	interstitial_loading = false
	interstitial_fail_count += 1

	_log("interstitial_ad_failed_to_show_full_screen_content")
	_log_obj("interstitial ad_info", ad_info)
	_log_obj("interstitial error_data", error_data)

	emit_signal("interstitial_closed")
	_end_fullscreen_ad()

	if interstitial_fail_count < INTERSTITIAL_FAIL_THRESHOLD:
		load_interstitial()


func _on_admob_interstitial_ad_dismissed_full_screen_content(ad_info: AdInfo) -> void :
	interstitial_loaded = false
	interstitial_loading = false
	interstitial_fail_count = 0

	_log("interstitial_ad_dismissed_full_screen_content")
	_log_obj("interstitial ad_info", ad_info)

	emit_signal("interstitial_closed")
	_end_fullscreen_ad()
	load_interstitial()






func load_banner() -> void :
	_log("load_banner() ignored: banner ads are disabled")


func show_banner() -> void :
	_log("show_banner() ignored: banner ads are disabled")


func show_banner_ad() -> void :
	show_banner()
