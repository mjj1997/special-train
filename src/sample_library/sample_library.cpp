#include <special_train/sample_library.hpp>

#include <format>
#include <iostream>
#include <print>
#include <string>

int factorial(int input) noexcept
{
  int result = 1;

  while (input > 0) {
    result *= input;
    --input;
  }

  return result;
}

void greeting()
{
  const int version{ 23 };
  std::string greeting{ std::format("Hello, C++{}", version) };
  std::cout << "Hello, World!" << '\n';
  std::println("{}", greeting);
}
