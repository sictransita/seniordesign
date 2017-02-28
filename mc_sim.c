#include <stdio.h>

#define ITERATIONS 10000;
#define ALPHA 2.3;
#define BETA 3.1;
#define MU 1.2;
#define DT 0.001;
#define SIGMA_0 = 3.4;
#define S_0 = 100.0;

// variable arrays
float sigma[] = new float[ITERATIONS];
float q[] = new float[ITERATIONS];
float w[] = new float[ITERATIONS];
float s[] = new float[ITERATIONS];

int main()
{
  int lambda;
  int epsilon;
  int sigma_sq;
  int prev_sigma_sq;

  // set initial sigma in array
  sigma[0] = SIGMA_0;
  s[0] = S_0;
  q[0] = 0.0;
  w[0] = 0.0;
  prev_sigma_sq = SIGMA_0 * SIGMA_0;

  // calculate core inputs
  for (int i = 1; i < ITERATIONS; i++) {
    lambda = math.random();
    epsilon = math.random();

    // sigma calculations
    sigma_sq = sigma[0] + (ALPHA * prev_sigma_sq) + (BETA * prev_sigma_sq * lambda * lambda);
    prev_sigma_sq = sigma_sq;
    sigma[i] = math.sqrt(sigma_sq);

    // core input calculations
    q[i] = (1 + MU * DT) - sigma_sq * DT * 0.5;
    w[i] = math.sqrt(DT) * sigma[i];

    // stock price calculations
    s[i] = q[i] + epsilon * w[i];
  }
  return 0;
}
