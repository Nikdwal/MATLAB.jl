using REPL
using REPL.LineEdit

const orange = "\e[38;5;166m"
const prompt = "MATLAB> "

function repl_eval(script::String, stdout::IO, stderr::IO)
    eval_string(script)
end

function createMatlabRepl(repl, main)
    mat_mode = LineEdit.Prompt(prompt;
    prompt_prefix=orange,
    prompt_suffix=main.prompt_suffix,
    sticky=true);

    hp = main.hist
    hp.mode_mapping[:r] = mat_mode
    mat_mode.hist = hp
    mat_mode.on_enter = (s) -> true
    mat_mode.on_done = (s, buf, ok) -> begin
        if !ok
            return REPL.transition(s, :abort)
        end
        script = String(take!(buf))
        if !isempty(strip(script))
            REPL.reset(repl)
            try
                repl_eval(script, repl.t.out_stream, repl.t.err_stream)
            catch y
                # should never reach
                # TODO
                #simple_showerror(repl.t.err_stream, y)
            end
        end
        REPL.prepare_next(repl)
        REPL.reset_state(s)
        s.current_mode.sticky || REPL.transition(s, main)
    end

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    prefix_prompt, prefix_keymap = LineEdit.setup_prefix_keymap(hp, mat_mode)


    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    mk = REPL.mode_keymap(main)

    b = Dict{Any,Any}[
        skeymap, mk, prefix_keymap, LineEdit.history_keymap,
        LineEdit.default_keymap, LineEdit.escape_defaults
    ]
    mat_mode.keymap_dict = LineEdit.keymap(b)

    mat_mode

end

function initializeMatlabRepl(repl = Base.active_repl, initkey = '\'')
    mirepl = isdefined(repl,:mi) ? repl.mi : repl
    main_mode = mirepl.interface.modes[1]
    mat_mode = createMatlabRepl(mirepl, main_mode)
    push!(mirepl.interface.modes,mat_mode)

    mat_prompt_keymap = Dict{Any,Any}(
        initkey => function (s,args...)
            if isempty(s) || position(LineEdit.buffer(s)) == 0
                buf = copy(LineEdit.buffer(s))
                LineEdit.transition(s, mat_mode) do
                    LineEdit.state(s, mat_mode).input_buffer = buf
                end
            else
                LineEdit.edit_insert(s, initkey)
            end
        end
    )

    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, mat_prompt_keymap);
    nothing
end

function matlabReplInitialized(repl)
    mirepl = isdefined(repl,:mi) ? repl.mi : repl
    any(:prompt in fieldnames(typeof(m)) && m.prompt == prompt for m in mirepl.interface.modes)
end
