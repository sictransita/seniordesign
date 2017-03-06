#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#ifndef max
#define max(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })
#endif
#define ITERATIONS 252 // days in stock market per year
#define ALPHA 0.03
#define BETA 0.013
#define MU 0.2
#define DT 1
#define R 0.02

double sigma[ITERATIONS] = {1.2};
double s[ITERATIONS] = {100.0};
double q[ITERATIONS] = {0.0};
double w[ITERATIONS] = {0.0};

static double stock_price() {
  for (int i = 1; i < ITERATIONS; i++) {
    double lambda = (double)rand()/(double)(RAND_MAX);
    double epsilon = (double)rand()/(double)(RAND_MAX);
    double temp = sigma[0] + ALPHA * sigma[i-1] * sigma[i-1] + BETA * sigma[i-1] * sigma[i-1] * lambda * lambda;
    sigma[i] = sqrt(temp);
    q[i] = 1 + MU*DT - temp * DT * 0.5;
    w[i] = sigma[i] * sqrt(DT);
    s[i] = s[i-1] * (q[i] + epsilon * w[i]);
    // printf("previous stock is %f\n", s[i-1]);
    // printf("stock is %f\n", s[i]);
  }
  return s[ITERATIONS - 1];
}

static double payoff(double s_final, double k) {
  double payoff = max(0.0, s_final - k);
  return payoff * exp(-R);
}

int main () {
  // begin timing
  clock_t begin = clock();

  // sigma[0] = 1.2;
  // s[0] = 100.0;
  // q[0] = 0.0;
  // w[0] = 0.0;

  double sum_payoff = 0.0;
  double avg_payoff = 0.0;
  double temp = 0.0;
  double stock = 0.0;

  // find the stock price with payoff and sum up
  for (int i = 0; i < 30; i++) {
    stock = stock_price();
    temp = payoff(stock, 110.0);
    sum_payoff = sum_payoff + temp;
  }
  avg_payoff = sum_payoff / 30.0;

  // end timing
  clock_t end = clock();
  double time_spent = (double)(end - begin) / CLOCKS_PER_SEC;

  printf("The average payoff is %f\n", avg_payoff);
  printf("The program took %f seconds to execute", time_spent);

  return 0;
}
