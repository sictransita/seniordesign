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
  #define ALPHA 0.155900
  #define BETA 0.840000
  #define MU 0.02268
  #define DT 0.003968
  #define R 0.02268
  #define barrier 2340.0
  #define k 2330.0

  double sigma[ITERATIONS] = {0.042377};
  double s[ITERATIONS] = {2328.95};
  double q[ITERATIONS] = {0.0};
  double w[ITERATIONS] = {0.0};

  static double stock_price() {
    char broke = 0;
    double lambda = 0.0;
    double epsilon = 0.0;
    for (int i = 1; i < ITERATIONS; i++) {
      double rand1 = (double)rand()/(double)(RAND_MAX);
      if (rand1 < 1.0) {
        lambda = rand1;
      }
      else {
        lambda = 0.0;
      }
      double rand2 = (double)rand()/(double)(RAND_MAX);
      if (rand2 < 1.0) {
        epsilon = rand2;
      }
      else {
        epsilon = 0.0;
      }
      double temp = sigma[0] + ALPHA * sigma[i-1] * sigma[i-1] + BETA * sigma[i-1] * sigma[i-1] * lambda * lambda;
      sigma[i] = sqrt(temp);
      q[i] = 1 + MU*DT - temp * DT * 0.5;
      w[i] = sigma[i] * sqrt(DT);
      s[i] = s[i-1] * (q[i] + epsilon * w[i]);
      if (s[i] > barrier) {
        broke = 1;
      }
      else {
        // nothing
      }
      // printf("previous stock is %f\n", s[i-1]);
      // printf("stock is %f\n", s[i]);
    }
    if (broke == 1) {
      return s[ITERATIONS-1];
    }
    else {
      return 0.0;
    }
  }

  static double payoff(double s_final, double strike) {
    double payoff = max(0.0, s_final - strike);
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
    for (int i = 0; i < 65536; i++) {
      stock = stock_price();
      temp = payoff(stock, k);
      sum_payoff = sum_payoff + temp;
    }
    avg_payoff = sum_payoff / 65536.0;

    // end timing
    clock_t end = clock();
    double time_spent = (double)(end - begin) / CLOCKS_PER_SEC;

    printf("The average payoff is %f\n", avg_payoff);
    printf("The program took %f seconds to execute", time_spent);

    return 0;
  }
