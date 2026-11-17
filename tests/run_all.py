from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
lua_tests=['test_lyrics_malformed.lua','test_lyric_layout_cache.lua','test_audit_repairs.lua','test_artist_throttle.lua','test_core.lua','test_spotify.lua','test_lyrics_online.lua','test_lyrics_session.lua','test_choice_store.lua','test_app.lua','test_integration.lua','test_e2e.lua','test_view.lua','test_runtime.lua','test_http.lua','test_covers.lua','test_device_regressions.lua','test_multilingual.lua','test_review_fixes.lua','test_detailed_review.lua','test_lyrics_cache.lua','test_cancel_group.lua','test_artist_store.lua','test_artist_info.lua','test_selection_flow.lua']
py_tests=['test_cache_cleanup.py','test_choice_recovery.py','test_recovery_order.py','test_config_gui.py','test_device_export.py','test_lyrics_provider.py','test_session_limit.py','test_watchdog.py','test_http_wire.py']
for name in lua_tests:
 subprocess.run(['luajit',str(root/'tests'/name)],check=True)
for name in py_tests:
 subprocess.run([sys.executable,str(root/'tests'/name)],check=True)
print('All portable host checks passed.')
