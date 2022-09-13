# despikeEEG
User interface for managing artifactual high amplitude spikes for EEG datasets.
Removes artifactual spikes from optimal point by minimizing the baseline difference.

User options:
Z-score threshold, with adjustable separating resolution.
Kurtosis threshold
Adjustable buffer length (Button to be added)
Ratio for rejection with bypass option.
Number of windows used in Z-score calculation

input: data structure in fieldtrip form - see initialize_vars_ft (link)
output: data structure containing bad intervals and pruned signal

Perform surrogate injection using surrogate data similar to inpainting.
data = gap_inpaint(data)

![Computing in the GUI app image](https://raw.githubusercontent.com/tommivayrynen1/despikeEEG/master/screenshot.png)


![Computing in the GUI app image](https://raw.githubusercontent.com/tommivayrynen1/despikeEEG/master/screenshot2.png)
