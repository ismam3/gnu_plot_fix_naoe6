#include <iostream>
#include <cmath>
#include <cstdio>
using namespace std;

int main ()
{
    // System Parameters
    double m = 75.0;
    double c = 40.0;
    double k = 500.0;

    // Initial Conditions
    double z = 0.5;
    double v = 0.0;

    // Simulation Settings
    double dt = 0.01;
    double t_max = 20.0;

    // Open a pipe to Gnuplot
    FILE* gp = popen("gnuplot -persistent", "w");
    fprintf(gp, "set title 'Heaving Motion (Damped Oscillator)'\n");
    fprintf(gp, "set xlabel 'Time (s)'\n");
    fprintf(gp, "set ylabel 'Displacement / Velocity'\n");
    fprintf(gp, "set grid\n");
    fprintf(gp, "plot '-' with lines title 'z(t)' lw 2, '-' with lines title 'v(t)' lw 2\n");

    // First pass: Calculate and plot displacement z(t)
    for (double t = 0.0; t <= t_max; t += dt) {
        fprintf(gp, "%lf %lf\n", t, z);
        double a = (-c * v - k * z) / m;
        v += a * dt;
        z += v * dt;
    }
    fprintf(gp, "e\n");

    // Reset initial conditions for second pass
    z = 0.5;
    v = 0.0;

    // Second pass: Calculate and plot velocity v(t)
    for (double t = 0.0; t <= t_max; t += dt) {
        fprintf(gp, "%lf %lf\n", t, v);
        double a = (-c * v - k * z) / m;
        v += a * dt;
        z += v * dt;
    }
    fprintf(gp, "e\n");

    // Flush buffer and close Gnuplot pipe
    fflush(gp);
    pclose(gp);

    return 0;
}
