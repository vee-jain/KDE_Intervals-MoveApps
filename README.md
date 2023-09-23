# KDE by weekly and monthly intervals

MoveApps

Github repository: (https://github.com/vee-jain/KDE_Intervals-MoveApps)

## Description
This app generates Kernel Density Estimations (KDE) at user-defined time intervals (i.e., weekly or monthly). The app visualizes KDE patterns over time and in maps along with the raw tracking data

## Documentation
For each weekly or monthly interval with more than 10 points, the KDE estimate is calculated at the 0.50 and 0.95 levels. This app calls on the 'hr_kde' function in the 'amt' package to do so. It does not account for autocorrelation and users should be mindful of the sampling rates and outliers in their datasets. Some concepts are outlined below, however users should refer to Signer et al (2011) for more details.

**Kernel Density Estimation (KDE)**: *KDE is a non-parametric way to estimate the probability density function of a continuous random variable. It is often used in spatial analysis and data visualization to estimate the distribution of points in space or time.*

**Kernel Function**: *At the heart of KDE is the kernel function, typically a probability density function like the Gaussian (normal) distribution. This kernel is centered at each data point and is used to smooth the data. The shape of the kernel determines the smoothness of the estimated density.*

**Calculating the Estimate**: *For each point in the dataset, the kernel is centered at that point, and its contribution is spread around that point based on the kernel shape and bandwidth. The contributions from all data points are summed to estimate the density at any given point in space or time.*

### Input data
move2 location object

### Output data
move2 location object (same as input)

### Artefacts
The app creates the following artefacts:

`kde_time_plots.pdf`: A PDF file containing KDE plots by interval.
`kde_df.csv`: A CSV file with KDE data.
`map_core_plot.html`: HTML file for 0.50 KDE maps.
`map_range_plot.html`: HTML file for 0.95 KDE maps.
`map_html_files.zip`: A ZIP archive containing HTML map files.

### Settings 
`Interval option`: Either weekly or monthly

### Most common errors
Please create an issue on the linked GitHub should any arise.

### Null or error handling
**Setting `Interval option`:** Default is monthly
