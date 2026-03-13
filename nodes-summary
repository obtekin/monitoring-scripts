#!/bin/bash
################################################################################
#
# Print detailed information about the available compute nodes
#
################################################################################


# Set output widths based on terminal size.
available_columns=$(tput cols)
if [[ $available_columns -le 80 ]]; then
    format="%15N %11T %.4c %.8z %.9m %.10d %8G %15f"
else
    # The default output is 80 columns wide. Calculate the remaining space
    # (leaving a little extra space to prevent wrapping to next line).
    extra_columns=$(( $available_columns - 85 ))
    margin=$(( $extra_columns / 8 ))

    gres_length=$(( $margin + 4 ))
    feature_length=$(( $margin + 10 ))

    format="%15N %11T %.4c %.8z %.9m %.5d %${gres_length}G %${feature_length}f"
fi

sinfo --format="${format}"
