import importlib.machinery
import importlib.util
import pathlib
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).with_name("ibus-taigi")
LOADER = importlib.machinery.SourceFileLoader("ibus_taigi", str(MODULE_PATH))
SPEC = importlib.util.spec_from_loader("ibus_taigi", LOADER)
ibus_taigi = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ibus_taigi)


class IBusEventTest(unittest.TestCase):
    def test_component_started_by_ibus_claims_xml_name(self):
        bus = mock.Mock()
        ibus = mock.Mock()
        ibus.Bus.return_value = bus
        loop = mock.Mock()
        glib = mock.Mock()
        glib.MainLoop.return_value = loop

        with mock.patch.object(ibus_taigi, "IBus", ibus), \
                mock.patch.object(ibus_taigi, "GLib", glib), \
                mock.patch.object(ibus_taigi, "Factory"):
            ibus_taigi.main()

        bus.request_name.assert_called_once_with("org.taigikeyboard.IBus", 0)
        bus.register_component.assert_not_called()
        loop.run.assert_called_once_with()

    def test_delete_response_deletes_one_character_from_document(self):
        class FakeEngine:
            rust = type("Rust", (), {"command": lambda self, _: "preedit=\ncomposing=false\ndelete=1\n"})()
            candidates = []
            composing = False

            def __init__(self):
                self.deletes = []
                self.preedits = []
                self.lookups = []

            def delete_surrounding_text(self, offset, count):
                self.deletes.append((offset, count))

            def update_preedit_text(self, text, cursor, visible):
                self.preedits.append((text.text, cursor, visible))

            def update_lookup_table(self, table, visible):
                self.lookups.append(visible)

        engine = FakeEngine()
        ibus_taigi.TaigiEngine.apply(engine, "backspace")
        self.assertEqual(engine.deletes, [(-1, 1)])

    def test_key_release_is_not_processed(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        release = ibus_taigi.IBus.ModifierType.RELEASE_MASK
        self.assertFalse(engine.do_process_key_event(ibus_taigi.IBus.KEY_a, 0, release))

    def test_backspace_is_only_consumed_while_composing(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = False
        engine.candidates = []
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertFalse(
            engine.do_process_key_event(ibus_taigi.IBus.KEY_BackSpace, 0, 0)
        )
        self.assertEqual(commands, [])

        engine.composing = True
        self.assertTrue(
            engine.do_process_key_event(ibus_taigi.IBus.KEY_BackSpace, 0, 0)
        )
        self.assertEqual(commands, ["backspace"])

    def test_space_is_only_consumed_while_composing(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = False
        engine.candidates = []
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertFalse(engine.do_process_key_event(ibus_taigi.IBus.KEY_space, 0, 0))
        self.assertEqual(commands, [])

        engine.composing = True
        self.assertTrue(engine.do_process_key_event(ibus_taigi.IBus.KEY_space, 0, 0))
        self.assertEqual(commands, ["select=0"])

    def test_shift_tap_toggles_language_mode(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = False
        engine.candidates = []
        engine.apply = lambda command: self.fail(
            "a mode switch with no composition must not call the engine"
        )
        engine.shift_tap = ibus_taigi.ShiftTapTracker(
            clock=iter([1.0, 1.1]).__next__
        )

        self.assertFalse(engine.do_process_key_event(ibus_taigi.IBus.KEY_Shift_L, 0, 0))
        self.assertFalse(
            engine.do_process_key_event(
                ibus_taigi.IBus.KEY_Shift_L,
                0,
                ibus_taigi.IBus.ModifierType.RELEASE_MASK,
            )
        )
        self.assertEqual(engine.language_mode, "english")

    def test_shift_tap_clears_active_composition(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = ["residue"]
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(
            clock=iter([1.0, 1.1]).__next__
        )

        self.assertFalse(engine.do_process_key_event(ibus_taigi.IBus.KEY_Shift_L, 0, 0))
        self.assertFalse(
            engine.do_process_key_event(
                ibus_taigi.IBus.KEY_Shift_L,
                0,
                ibus_taigi.IBus.ModifierType.RELEASE_MASK,
            )
        )
        self.assertEqual(commands, ["reset"])
        self.assertEqual(engine.language_mode, "english")
        self.assertFalse(engine.composing)
        self.assertEqual(engine.candidates, [])

    def test_shift_plus_letter_is_not_a_mode_switch(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = False
        engine.candidates = []
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(
            clock=iter([1.0, 1.1]).__next__
        )

        self.assertFalse(engine.do_process_key_event(ibus_taigi.IBus.KEY_Shift_L, 0, 0))
        self.assertTrue(
            engine.do_process_key_event(
                ord("A"),
                0,
                ibus_taigi.IBus.ModifierType.SHIFT_MASK,
            )
        )
        self.assertFalse(
            engine.do_process_key_event(
                ibus_taigi.IBus.KEY_Shift_L,
                0,
                ibus_taigi.IBus.ModifierType.RELEASE_MASK,
            )
        )
        self.assertEqual(engine.language_mode, "taigi")
        self.assertEqual(commands, ["append=A"])

    def test_standard_candidate_slots_use_free_letters_not_tone_digits(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(engine.do_process_key_event(ord("q"), 0, 0))
        self.assertTrue(engine.do_process_key_event(ord("5"), 0, 0))
        self.assertEqual(commands, ["select=0", "append=5"])

    def test_shifted_candidate_slot_is_text(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = ["one"]
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(
            engine.do_process_key_event(
                ord("Q"),
                0,
                ibus_taigi.IBus.ModifierType.SHIFT_MASK,
            )
        )
        self.assertEqual(commands, ["append=Q"])

    def test_candidate_slot_labels_match_the_keys(self):
        self.assertEqual(ibus_taigi.CANDIDATE_SLOT_KEYS, "qwdfzxvy")

    def test_semicolon_shows_the_next_eight_candidates(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = [f"candidate-{index}" for index in range(12)]
        engine.lookup_table = ibus_taigi.IBus.LookupTable.new(
            ibus_taigi.CANDIDATE_PAGE_SIZE, 0, False, False
        )
        for candidate in engine.candidates:
            engine.lookup_table.append_candidate(
                ibus_taigi.IBus.Text.new_from_string(candidate)
            )
        shown = []
        engine.update_lookup_table = lambda table, visible: shown.append(
            (table.get_cursor_pos(), visible)
        )
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(
            engine.do_process_key_event(ibus_taigi.IBus.KEY_semicolon, 0, 0)
        )
        self.assertEqual(shown, [(8, True)])

    def test_shift_page_down_shows_the_previous_page(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = [f"candidate-{index}" for index in range(12)]
        engine.lookup_table = ibus_taigi.IBus.LookupTable.new(
            ibus_taigi.CANDIDATE_PAGE_SIZE, 0, False, False
        )
        for candidate in engine.candidates:
            engine.lookup_table.append_candidate(
                ibus_taigi.IBus.Text.new_from_string(candidate)
            )
        engine.lookup_table.page_down()
        shown = []
        engine.update_lookup_table = lambda table, visible: shown.append(
            (table.get_cursor_pos(), visible)
        )
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(
            engine.do_process_key_event(
                ibus_taigi.IBus.KEY_Page_Down,
                0,
                ibus_taigi.IBus.ModifierType.SHIFT_MASK,
            )
        )
        self.assertEqual(shown, [(0, True)])

    def test_brackets_page_through_candidates(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = [f"candidate-{index}" for index in range(12)]
        engine.lookup_table = ibus_taigi.IBus.LookupTable.new(
            ibus_taigi.CANDIDATE_PAGE_SIZE, 0, False, False
        )
        for candidate in engine.candidates:
            engine.lookup_table.append_candidate(
                ibus_taigi.IBus.Text.new_from_string(candidate)
            )
        shown = []
        engine.update_lookup_table = lambda table, visible: shown.append(
            (table.get_cursor_pos(), visible)
        )
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(
            engine.do_process_key_event(ibus_taigi.IBus.KEY_bracketright, 0, 0)
        )
        self.assertEqual(shown, [(8, True)])

        self.assertTrue(
            engine.do_process_key_event(ibus_taigi.IBus.KEY_bracketleft, 0, 0)
        )
        self.assertEqual(shown, [(8, True), (0, True)])

    def test_shifted_brackets_remain_text(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = ["candidate"]
        engine.lookup_table = ibus_taigi.IBus.LookupTable.new(
            ibus_taigi.CANDIDATE_PAGE_SIZE, 0, False, False
        )
        engine.lookup_table.append_candidate(
            ibus_taigi.IBus.Text.new_from_string("candidate")
        )
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(
            engine.do_process_key_event(
                ibus_taigi.IBus.KEY_bracketleft,
                0,
                ibus_taigi.IBus.ModifierType.SHIFT_MASK,
            )
        )
        self.assertEqual(commands, ["append=["])

    def test_candidate_key_selects_from_the_visible_page(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.candidates = [f"candidate-{index}" for index in range(12)]
        engine.lookup_table = ibus_taigi.IBus.LookupTable.new(
            ibus_taigi.CANDIDATE_PAGE_SIZE, 0, False, False
        )
        for candidate in engine.candidates:
            engine.lookup_table.append_candidate(
                ibus_taigi.IBus.Text.new_from_string(candidate)
            )
        engine.lookup_table.page_down()
        commands = []
        engine.apply = commands.append
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)

        self.assertTrue(engine.do_process_key_event(ord("q"), 0, 0))
        self.assertEqual(commands, ["select=8"])

    def test_candidate_click_is_relative_to_the_visible_page(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.candidates = [f"candidate-{index}" for index in range(12)]
        engine.lookup_table = ibus_taigi.IBus.LookupTable.new(
            ibus_taigi.CANDIDATE_PAGE_SIZE, 0, False, False
        )
        for candidate in engine.candidates:
            engine.lookup_table.append_candidate(
                ibus_taigi.IBus.Text.new_from_string(candidate)
            )
        engine.lookup_table.page_down()
        commands = []
        engine.apply = commands.append

        engine.do_candidate_clicked(2, 1, 0)
        self.assertEqual(commands, ["select=10"])

    def test_ctrl_shift_d_opens_separate_online_candidate_list(self):
        engine = ibus_taigi.TaigiEngine.__new__(ibus_taigi.TaigiEngine)
        engine.language_mode = "taigi"
        engine.composing = True
        engine.preedit = "愛"
        engine.candidates = ["local candidate"]
        engine.local_candidates = []
        engine.online_mode = False
        engine.online_entries = []
        engine.online_dictionary = mock.Mock()
        engine.online_dictionary.lookup.return_value = [
            {"display": "愛  thiànn", "commit": "愛"}
        ]
        engine.shift_tap = ibus_taigi.ShiftTapTracker(clock=iter([]).__next__)
        engine.update_lookup_table = lambda table, visible: None
        engine.apply = mock.Mock()
        engine.commit_text = mock.Mock()

        self.assertTrue(
            engine.do_process_key_event(
                ibus_taigi.IBus.KEY_d,
                0,
                ibus_taigi.IBus.ModifierType.CONTROL_MASK
                | ibus_taigi.IBus.ModifierType.SHIFT_MASK,
            )
        )
        self.assertEqual(engine.candidates, ["線上台日｜愛  thiànn"])
        self.assertTrue(engine.online_mode)

        self.assertTrue(engine.do_process_key_event(ord("q"), 0, 0))
        engine.apply.assert_called_once_with("reset")
        engine.commit_text.assert_called_once_with(
            mock.ANY
        )
        self.assertFalse(engine.online_mode)


if __name__ == "__main__":
    unittest.main()
