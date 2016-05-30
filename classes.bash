# @description Creates instance of specified class.
#
# @example
#     classes:new ClassName var 12345
#     $var::methodFoo
#
# @arg1 string Name of class which should be created
# @arg2 string Name of variable which will be set to instance.
# @arg3 string Unique object identifier.
#
# @see classes:require
classes:new() {
    local __class="$1"
    local __object="$2"
    local __identifier="${3:-$RANDOM}"

    local __namespace=":classes:objects:${__class}:${__identifier}"

    local __definition=$(
        :classes:get-object-definition \
            "$__class" "$__namespace" "$__identifier"
    )

    builtin eval $__object=\$__namespace

    builtin eval "$__definition"

    if typeset -f "${__namespace}::constructor" &>/dev/null; then
        builtin eval "${__namespace}::constructor"
    fi
}

# @description Source file with class declaration.
#
# Class should be declared using following syntax:
#
# ```bash
#    @class ClassName
#
#        @method methodFoo() {
#              # here is available two variables
#              # $this refers to current instance
#              # $identifier string representation of object identifier
#              echo "Was created with following identifier: $identifier"
#              $this::methodBar arg1
#        }
#
#        @method methodBar() {
#              echo "There is same identifier: $identifier"
#              echo "args: $@"
#        }
# ```
#
# @class  - declare new class
# @method - declare new method
#
# @example
#     classes:require foo.class.sh
#     classes:new Foo var 12345
#     $var::methodFoo
#
# @arg1 string Name of class which should be created
classes:require() {
    local __filename="$1"

    local __class=""
    local __method_scope=""

    alias '@class'=':classes:define-class'
    alias '@method'=':classes:define-method;'

    local __shopt="$(shopt -p)"
    shopt -s expand_aliases

    builtin source "$__filename"

    :classes:define-method

    eval "$__shopt"

    unalias '@class'
    unalias '@method'

}

:classes:get-object-definition() {
    local __class="$1"
    local __namespace="$2"
    local __identifier="$3"

    declare -F \
        | grep -F -- '-f :class:'$__class'::' \
        | cut -d: -f5 \
        | sed -re \
            's|.*|'${__namespace}'::&() { \
    :class:'${__class}'::& "'${__identifier}'" "${@}"; \
};|'
}

:classes:define-class() {
    :classes:define-method
    __class="$@"
}

:classes:define-method() {
    local __actual_scope=$(:classes:get-scope)
    if [[ "$__actual_scope" = "$__method_scope" ]]; then
        return 0
    fi

    if [[ "$__method_scope" ]]; then
        for __function in ${__actual_scope[@]}; do
            if grep -Fq -- "$__function" <<< "$__method_scope"; then
                continue
            fi

            local __definition="$(
                :classes:get-method-definition "$__class" "$__function"
            )"

            builtin eval "$__definition"
            unset "$__function"

            break
        done
    fi

    __method_scope="$__actual_scope"
}

:classes:get-scope() {
    declare -F | cut -d' ' -f3 | grep -v '^:class:'
}

:classes:get-method-definition() {
    local __class="$1"
    local __function="$2"
    cat <<-METHOD
:class:${__class}::${__function} () {
    local identifier="\$1"
    local this=":classes:objects:${__class}:\${identifier}"
    shift
$(declare -f "$__function" | tail -n+3)
METHOD
}
