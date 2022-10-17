namespace HookRouter {
    dictionary hooksByType;
    array<MLHook::PendingEvent@> pendingEvents;
    dictionary hooksByPlugin;

    void MainCoro() {
        pendingEvents.Reserve(100);
        while (true) {
            yield();
            for (uint i = 0; i < pendingEvents.Length; i++) {
                auto event = pendingEvents[i];
                // trace('got event for type: ' + type + ' with data of len: ' + data.Length);
                auto hs = cast<array<MLHook::HookMLEventsByType@> >(hooksByType[event.type]);
                // hs can be null if a hook was unloaded before an event is processed
                if (hs !is null) {
                    for (uint i = 0; i < hs.Length; i++) {
                        auto hook = hs[i];
                        // hook.OnEvent(event.type, event.data);
                        uint startTime = Time::Now;
                        hook.OnEvent(event);
                        if (Time::Now - startTime > 1) {
                            warn('Event processing for hook of type ' + hook.type + ' took ' + (Time::Now - startTime) + ' ms! Removing the hook for performance reasons.');
                            UnregisterMLHook(hook);
                            i--;
                        }
                    }
                }
            }
            pendingEvents.RemoveRange(0, pendingEvents.Length);
        }
    }

    void RegisterMLHook(MLHook::HookMLEventsByType@ hookObj, const string &in _type = "") {
        if (hookObj is null) {
            warn("RegisterMLHook was passed a null hook object!");
            return;
        }
        string type = _type.Length == 0 ? hookObj.type : _type;
        if (type.StartsWith(MLHook::EventPrefix)) {
            warn('RegisterMLHook given a type that starts with the event prefix (this is probably wrong)');
        }
        type = MLHook::EventPrefix + type;
        if (!hooksByType.Exists(type)) {
            @hooksByType[type] = array<MLHook::HookMLEventsByType@>();
        }
        auto hooks = cast< array<MLHook::HookMLEventsByType@> >(hooksByType[type]);
        if (hooks.FindByRef(hookObj) < 0) {
            hooks.InsertLast(hookObj);
            trace("registered MLHook event for type: " + type);
            OnHookRegistered(hookObj);
        } else {
            warn("Attempted to add hook object for type " + type + " more than once. Refusing.");
        }
    }

    void OnHookRegistered(MLHook::HookMLEventsByType@ hookObj) {
        auto plugin = Meta::ExecutingPlugin();
        if (!hooksByPlugin.Exists(plugin.ID)) {
            @hooksByPlugin[plugin.ID] = array<MLHook::HookMLEventsByType@>();
        }
        auto hooks = cast< array<MLHook::HookMLEventsByType@> >(hooksByPlugin[plugin.ID]);
        if (hooks.FindByRef(hookObj) < 0) {
            hooks.InsertLast(hookObj);
        }
    }

    void UnregisterExecutingPluginsMLHooks() {
        auto plugin = Meta::ExecutingPlugin();
        if (hooksByPlugin.Exists(plugin.ID)) {
            auto hooks = cast< array<MLHook::HookMLEventsByType@> >(hooksByPlugin[plugin.ID]);
            for (uint i = 0; i < hooks.Length; i++) {
                UnregisterMLHook(hooks[i]);
            }
        }
    }

    void UnregisterMLHook(MLHook::HookMLEventsByType@ hookObj) {
        auto types = hooksByType.GetKeys();
        string[] remTypes = {};
        for (uint i = 0; i < types.Length; i++) {
            auto hookType = types[i];
            auto hooks = cast<array<MLHook::HookMLEventsByType@> >(hooksByType[hookType]);
            int hookIx = hooks.FindByRef(hookObj);
            if (hookIx >= 0) hooks.RemoveAt(hookIx);
            if (hooks.Length == 0) {
                hooksByType.Delete(hookType);
                remTypes.InsertLast(hookType);
            }
        }
        if (remTypes.Length > 0) {
            trace('UnregisteredMLHook object for types: ' + string::Join(remTypes, ", "));
        }
    }

    void OnEvent(MLHook::PendingEvent@ event) {
        if (hooksByType.Exists(event.type)) {
            pendingEvents.InsertLast(event);
        }
    }
}
