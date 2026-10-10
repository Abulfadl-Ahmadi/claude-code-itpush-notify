import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_install_script_preserves_existing_settings_and_is_idempotent():
    source = (ROOT / "installers" / "install.sh").read_text(encoding="utf-8")
    assert "setdefault('hooks',{})" in source
    assert "itpush-notify/notify.sh" in source
    assert "os.replace(staged_settings,settings_path)" in source


def test_static_messages_do_not_read_transcript_or_title():
    for filename in ("notify.sh", "notify.ps1"):
        text = (ROOT / "hooks" / filename).read_text(encoding="utf-8")
        assert "transcript" not in text.lower()
        assert "session_title" not in text.lower()
        assert "last_assistant_message" not in text.lower()


def test_notification_titles_and_messages_are_within_api_limits():
    import re
    text = (ROOT / "hooks" / "notify.sh").read_text(encoding="utf-8")
    title_values = re.findall(r"^\s*TITLE='(.*)'$", text, flags=re.M)
    message_values = re.findall(r"^\s*MESSAGE='(.*)'$", text, flags=re.M)
    assert title_values and message_values
    assert all(len(value) <= 80 for value in title_values)
    assert all(len(value) <= 240 for value in message_values)


if __name__ == "__main__":
    for name, func in sorted(globals().items()):
        if name.startswith("test_") and callable(func):
            func()
            print(f"PASS: {name}")
