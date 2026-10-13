import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading";
import { application } from "controllers/application";
import TimezoneCookieController from "controllers/timezone_cookie_controller";
import HotkeyHintController from "controllers/hotkey_hint_controller";

application.register("timezone-cookie", TimezoneCookieController); // always eager
application.register("hotkey-hint", HotkeyHintController); // always eager
lazyLoadControllersFrom("controllers", application); // everything else on demand
