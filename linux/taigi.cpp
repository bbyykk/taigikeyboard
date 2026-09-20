#include <fcitx/candidatelist.h>
#include <fcitx/event.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputcontextproperty.h>
#include <fcitx/inputmethodengine.h>
#include <fcitx/inputpanel.h>
#include <fcitx/text.h>
#include <fcitx-utils/keysym.h>
#include <fcitx-utils/utf8.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>
#include <memory>
#include <string>
#include <vector>

extern "C" int taigi_linux_init(const char *);
extern "C" char *taigi_linux_command(const char *);
extern "C" void taigi_linux_free(char *);

namespace fcitx {

class State;
class SelectableCandidate final : public CandidateWord {
public:
    SelectableCandidate(Text text, State *state, size_t index)
        : CandidateWord(std::move(text)), state_(state), index_(index) {}
    void select(InputContext *) const override;
private:
    State *state_;
    size_t index_;
};

class State final : public InputContextProperty {
public:
    explicit State(InputContext *ic) : ic_(ic) {}

    void update(const std::string &command) {
        char *raw = taigi_linux_command(command.c_str());
        if (!raw) return;
        std::string result(raw);
        taigi_linux_free(raw);
        bool composing = false;
        std::string preedit;
        std::vector<std::string> candidates;
        for (size_t pos = 0; pos < result.size();) {
            size_t end = result.find('\n', pos);
            if (end == std::string::npos) end = result.size();
            auto line = result.substr(pos, end - pos);
            if (line.rfind("preedit=", 0) == 0) preedit = unescape(line.substr(8));
            else if (line.rfind("composing=", 0) == 0) composing = line.substr(10) == "true";
            else if (line == "candidates_begin=1") candidates.clear();
            else if (line.rfind("candidate=", 0) == 0) {
                auto tab = line.find('\t');
                if (tab != std::string::npos) candidates.push_back(unescape(line.substr(tab + 1)));
            }
            else if (line.rfind("commit=", 0) == 0) ic_->commitString(unescape(line.substr(7)));
            else if (line == "delete=1") ic_->deleteSurroundingText(-1, 1);
            pos = end + (end < result.size());
        }
        candidates_ = std::move(candidates);
        ic_->inputPanel().reset();
        if (composing && !preedit.empty()) ic_->inputPanel().setPreedit(Text(preedit, TextFormatFlag::Underline));
        if (!candidates_.empty()) {
            auto list = std::make_unique<CommonCandidateList>();
            // Match the horizontal candidate rows used by the other desktop
            // front ends instead of Fcitx's default vertical layout.
            list->setLayoutHint(CandidateLayoutHint::Horizontal);
            for (size_t i = 0; i < candidates_.size(); ++i)
                list->append<SelectableCandidate>(Text(candidates_[i]), this, i);
            ic_->inputPanel().setCandidateList(std::move(list));
        }
        ic_->updatePreedit();
        ic_->updateUserInterface(UserInterfaceComponent::InputPanel);
        composing_ = composing;
    }

    bool composing() const { return composing_; }
    size_t candidateCount() const { return candidates_.size(); }
    void reset() { update("reset"); candidates_.clear(); composing_ = false; }

private:
    static std::string unescape(const std::string &value) {
        std::string out; bool escaped = false;
        for (char c : value) { if (escaped) { out += c == 'n' ? '\n' : (c == 't' ? '\t' : c); escaped = false; } else if (c == '\\') escaped = true; else out += c; }
        return out;
    }
    InputContext *ic_;
    bool composing_ = false;
    std::vector<std::string> candidates_;
};

void SelectableCandidate::select(InputContext *) const {
    state_->update("select=" + std::to_string(index_));
}

class Engine final : public InputMethodEngine {
public:
    explicit Engine(Instance *instance) : instance_(instance), factory_([](InputContext &ic) { return new State(&ic); }) {
        instance_->inputContextManager().registerProperty("taigi-state", &factory_);
        initialized_ = taigi_linux_init(TAIGI_DICT_DIR) != 0;
    }
    void activate(const InputMethodEntry &, InputContextEvent &event) override { if (!initialized_) return; event.inputContext()->propertyFor(&factory_)->reset(); }
    void reset(const InputMethodEntry &, InputContextEvent &event) override { if (initialized_) event.inputContext()->propertyFor(&factory_)->reset(); }
    void deactivate(const InputMethodEntry &entry, InputContextEvent &event) override { reset(entry, event); }
    void keyEvent(const InputMethodEntry &, KeyEvent &event) override {
        if (!initialized_ || event.isRelease()) return;
        auto *state = event.inputContext()->propertyFor(&factory_);
        auto key = event.key();
        if (key.states().test(KeyState::Ctrl) && key.states().test(KeyState::Shift) &&
            key.sym() >= FcitxKey_1 && key.sym() <= FcitxKey_3) {
            state->update("mode=" + std::string(1, static_cast<char>(key.sym() - FcitxKey_1 + '1')));
            event.filterAndAccept();
            return;
        }
        if (key.sym() == FcitxKey_Escape) { state->reset(); event.filterAndAccept(); return; }
        if (key.sym() == FcitxKey_BackSpace) {
            if (state->composing()) {
                state->update("backspace");
                event.filterAndAccept();
            }
            return;
        }
        int selection = key.digitSelection();
        if (state->composing() && selection >= 0 && static_cast<size_t>(selection) < state->candidateCount()) {
            state->update("select=" + std::to_string(selection)); event.filterAndAccept(); return;
        }
        if (key.states().test(KeyState::Ctrl) || key.states().test(KeyState::Alt) || key.states().test(KeyState::Super)) return;
        auto sym = key.sym();
        if (sym >= FcitxKey_space && sym <= FcitxKey_asciitilde) {
            if (sym == FcitxKey_space && state->composing()) state->update("select=0");
            else state->update("append=" + std::string(1, static_cast<char>(sym)));
            event.filterAndAccept(); return;
        }
        if (sym == FcitxKey_Return || sym == FcitxKey_KP_Enter) { if (state->composing()) state->update("commit"); event.filterAndAccept(); }
    }
private:
    Instance *instance_;
    FactoryFor<State> factory_;
    bool initialized_ = false;
};

class Factory : public AddonFactory { public: AddonInstance *create(AddonManager *manager) override { return new Engine(manager->instance()); } };
}

FCITX_ADDON_FACTORY_V2(taigi, fcitx::Factory)
