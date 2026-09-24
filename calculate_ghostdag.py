import math

"""
Educational GHOSTDAG parameter calculator and test harness.

This module provides a small, self-contained reference implementation of the equations
used to derive GHOSTDAG's `k` parameter from network assumptions, together
with helper functions for exploring the relationship between:

    block time <-> blocks/second <-> anticone size expectation <-> GHOSTDAG k

The implementations mirror the algorithm used by Kaspa where practical while
favoring readability and mathematical transparency over production concerns.
The functions are intentionally written to emphasize clarity and correspondence
with the underlying mathematics rather than maximum performance.

Intended use:
    * Read the source alongside the PHANTOM/GHOSTDAG paper.
    * Run this file directly from an IDE or the command line to see example
      calculations and probability distributions.
    * Modify the test cases to explore alternative network
      assumptions (block rates, network delay, tail probability, etc.).
    * Use as a reference when learning how GHOSTDAG parameters are derived.

This module is not consensus-critical software and should not be considered a
drop-in replacement for the implementation used by Kaspa nodes.
"""

def calculate_anticone_size_expectation(blocks_per_second: float, max_network_delay: float = 5.0) -> float:
    """
    Computes the `anticone_size_expectation` parameter required as input to
    calculate_ghostdag_k.

    Background:
        Per the PHANTOM GHOSTDAG paper (eq. 1, section 4.2), x is defined as 2*D*λ, where:
          - D = maximal network delay (in seconds) that a block might take to
                propagate to all other nodes
          - λ = block mining rate (blocks per second)
        The factor of 2 accounts for the round-trip nature of delay: a block must
        propagate out (D seconds) and any concurrently mined block's existence must
        propagate back (another D seconds) before both are "seen" by all miners.

    Network assumptions:
        - round_trip = 2 (the "2" in "2Dλ")
        - max_network_delay defaults to 5 seconds, mirroring Kaspa's
          NETWORK_DELAY_BOUND, but can be overridden by the caller.

    Args:
        blocks_per_second: λ, the network's target block production rate.
        max_network_delay: D, the maximal network delay (in seconds) assumed for
            block propagation. Defaults to 5.0, mirroring Kaspa's
            NETWORK_DELAY_BOUND.

    Returns:
        anticone_size_expectation: the expected number of blocks that could be produced
           concurrently (i.e., in another node's anticone) within one round-trip max-delay
           window. This value is fed directly into calculate_ghostdag_k.
    """

    assert blocks_per_second > 0.0
    assert max_network_delay > 0.0

    round_trip = 2

    return round_trip * blocks_per_second * max_network_delay

def calculate_ghostdag_k(anticone_size_expectation_: float, max_tail_probability : float = 0.01) -> int:
    """
    Port of Kaspa's GHOSTDAG K-finding algorithm.

    Background:
        GHOSTDAG requires a parameter K such that, under normal network conditions,
        the anticone of any block (the set of blocks neither in its past nor future)
        will contain no more than K blocks, with high probability. Per the PHANTOM
        paper (eq. 1, section 4.2), anticone size follows a Poisson distribution with
        rate parameter `x` (anticone_size_expectation). This function finds the
        minimal K such that:

            P(anticone size > K) < max_tail_probability

        i.e., it walks the Poisson CDF term-by-term (poisson_term = x^k / k!) starting
        at k=0, accumulating cumulative_probability = P(anticone size <= k), until the
        remaining tail probability (1 - cumulative_probability) drops below
        max_tail_probability. The first k satisfying this is returned as min_k.

    Args:
        anticone_size_expectation_: x = 2*D*λ, the expected concurrent block count
            under max network delay assumptions. Must be > 0. Typically produced by
            calculate_anticone_size_expectation().
        max_tail_probability: delta, the desired upper bound on the probability that
            an anticone exceeds K in size. Must be strictly between 0 and 1.
            Kaspa mainnet uses 0.01 (GHOSTDAG_TAIL_DELTA).

    Returns:
        min_k: the minimal K satisfying the tail-probability bound above.
    """

    assert anticone_size_expectation_ > 0.0
    assert 0.0 < max_tail_probability < 1.0

    min_k = 0
    cumulative_probability_ = 0.0
    poisson_term = 1.0
    exp_neg_x = math.exp(-anticone_size_expectation_)

    while True:
        cumulative_probability_ += exp_neg_x * poisson_term
        if 1.0 - cumulative_probability_ < max_tail_probability:
            return min_k
        min_k += 1
        poisson_term *= anticone_size_expectation_ / min_k


def calculate_ghostdag_k_with_probability_distribution(
        anticone_size_expectation_: float, max_tail_probability: float = 0.01
) -> list[float]:
    """
    Computes the Poisson PMF P(n) for n = 0..min_k, where min_k is the minimal value
    calculate_ghostdag_k(anticone_size_expectation, max_tail_probability) would return.

    Background:
        Structurally identical to calculate_ghostdag_k -- same assertions, same
        Poisson-term recurrence, same while-True/early-return shape, same stopping
        condition (tail probability P(anticone size > n) < max_tail_probability).
        The only difference: instead of discarding each per-n probability after
        checking it, this function retains every one in a list before returning.

    Args:
        anticone_size_expectation_: x = 2*D*λ, the expected concurrent block count
            under max network delay assumptions. Must be > 0. Typically produced by
            calculate_anticone_size_expectation().
        max_tail_probability: delta, the desired upper bound on the probability that
            an anticone exceeds min_k in size. Must be strictly between 0 and 1.
            Kaspa mainnet uses 0.01 (GHOSTDAG_TAIL_DELTA).

    Returns:
        A list of floats of length min_k + 1, where:
          - index n (0 <= n <= min_k) holds P(anticone size == n)
          - index 0 is the probability that the honest network produces zero
            parallel blocks within one round-trip max-delay window (i.e., a
            single block "wins" the round with no concurrent competitors)
          - index 1 is the probability of exactly one parallel/concurrent block
            being produced alongside it, index 2 the probability of two, and so on
          - min_k is exactly the value calculate_ghostdag_k would return for the
            same arguments, i.e. len(result) - 1 == min_k
          - sum(result) == cumulative_probability (up to floating point precision) at termination, so
            1.0 - sum(result) is the tail probability P(anticone size > min_k),
            guaranteed to be < max_tail_probability by construction.
        This makes the list self-describing for later parsing: callers can recover
        min_k via len(result) - 1, and the tail-probability guarantee via
        1.0 - sum(result).
    """
    assert anticone_size_expectation_ > 0.0
    assert 0.0 < max_tail_probability < 1.0

    min_k = 0
    cumulative_probability_ = 0.0
    poisson_term = 1.0
    exp_neg_x = math.exp(-anticone_size_expectation_)
    probabilities_list = []

    while True:
        term = exp_neg_x * poisson_term
        cumulative_probability_ += term
        probabilities_list.append(term)
        if 1.0 - cumulative_probability_ < max_tail_probability:
            return probabilities_list
        min_k += 1
        poisson_term *= anticone_size_expectation_ / min_k


def block_time_ms_bounds_for_k(k_to_find_bounds: int) -> tuple[int, int]:
    """
    Returns (min_ms, max_ms) -- the inclusive range of integer block-creation
    times (in milliseconds) for which calculate_ghostdag_k(2 * max_network_delay / (ms / 1000),
    max_tail_probability) == k_to_find_bounds.

    Background:
        Since x = 2*D*bps = 2*D/(ms / 1000) (per the PHANTOM paper's 2Dλ formula,
        mirrored in calculate_ghostdag_k's doc comment), x is monotonically
        DECREASING as block-creation time (ms) increases. Because calculate_ghostdag_k
        is monotonically non-decreasing in x, k is monotonically NON-INCREASING
        in ms: short block times -> large k, long block times -> small k
        (down to k=0 as ms -> infinity).

        This means the set of integer `ms` values producing a given k is a
        contiguous inclusive range [min_ms, max_ms], found here by two
        independent integer binary searches:
          - min_ms: smallest ms such that k_of_ms(ms) <= k
            (the boundary where k+1 drops to k)
          - max_ms: largest ms such that k_of_ms(ms) >= k
            (the boundary where k drops to k-1)

    Network assumptions (fixed, mirroring Kaspa mainnet):
        - max_network_delay = 5.0 seconds (NETWORK_DELAY_BOUND)
        - max_tail_probability = 0.01 (GHOSTDAG_TAIL_DELTA)

    Args:
        k_to_find_bounds: The target GHOSTDAG k parameter. Must be an integer
                          in the range [1, 18].

    Returns:
        (min_ms, max_ms): The inclusive integer-millisecond range of block
        creation times that produce exactly this k value.

    Scope & Limitations:
        - Target k is constrained to [1, 18], which corresponds to block times
          >= 1.0 second (1000 ms; BPS <= 1.0).
        - k = 0 is intentionally excluded because it has no finite max_ms
          (it is the unbounded terminal state for all block times > ~16.5 minutes).
        - k >= 19 is excluded as it corresponds to sub-second block times
          (BPS > 1.0), where 1 ms discrete quantization introduces overlapping
          bounds and evaluation traps.

    """

    assert isinstance(k_to_find_bounds, int)
    assert 0 < k_to_find_bounds < 19

    max_network_delay = 5.0
    max_tail_probability = 0.01

    def k_of_ms(ms_: int) -> int:
        bps_ = 1000.0 / ms_
        anticone_size_expectation_ = 2.0 * max_network_delay * bps_

        return calculate_ghostdag_k(anticone_size_expectation_, max_tail_probability)

    lo, hi = 1, 1000
    while k_of_ms(hi) >= k_to_find_bounds:
        lo = hi
        hi *= 2

    while hi - lo > 1:
        mid = (lo + hi) // 2
        if k_of_ms(mid) >= k_to_find_bounds:
            lo = mid
        else:
            hi = mid
    max_ms = lo

    lo, hi = 1, max_ms
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if k_of_ms(mid) <= k_to_find_bounds:
            hi = mid
        else:
            lo = mid

    min_ms = hi

    return min_ms, max_ms


def format_duration(ms_to_convert: int) -> str:
    """
    Formats a duration in milliseconds into a human-readable string representation
    combining minutes, seconds, and milliseconds as appropriate.

    Args:
        ms_to_convert: Total duration in milliseconds.

    Returns:
        Formatted duration string (e.g., '100ms', '5s', '2s 500ms', '1m 30s 100ms').
    """
    seconds_, ms = divmod(ms_to_convert, 1000)
    minutes_, secs = divmod(seconds_, 60)

    if minutes_ == 0 and secs == 0:
        return f"{ms}ms"
    if minutes_ == 0:
        return f"{secs}s {ms}ms" if ms > 0 else f"{secs}s"

    parts = [f"{minutes_}m", f"{secs}s"]
    if ms > 0:
        parts.append(f"{ms}ms")
    return " ".join(parts)

# ===========================================================================
# INTERACTIVE CLI EXPLORER
# ===========================================================================

def _prompt_float(prompt_text: str, default_val: float, min_val: float = 0.0) -> float:
    """Helper to prompt for positive floats with fallback defaults."""
    while True:
        raw = input(f"{prompt_text} [default: {default_val}]: ").strip()
        if not raw:
            return default_val
        try:
            val = float(raw)
            if val > min_val:
                return val
            print(f"Error: Value must be greater than {min_val}.")
        except ValueError:
            print("Error: Invalid number. Please try again.")


def _prompt_bps_or_blocktime() -> float:
    """Helper to accept block rate either as BPS or Block Time in seconds."""
    print("\nHow would you like to specify block production rate?")
    print("  [1] Blocks Per Second (BPS)")
    print("  [2] Block Time (in seconds or ms)")
    choice = input("Select [1 or 2, default: 1]: ").strip()

    if choice == "2":
        sec = _prompt_float("Enter Block Time in seconds", default_val=1.0)
        return 1.0 / sec
    else:
        return _prompt_float("Enter Target Block Rate (λ in BPS)", default_val=1.0)


def _format_rate_or_duration(bps: float) -> str:
    """Formats BPS and corresponding block time cleanly without excess zeros."""
    block_time_sec = 1.0 / bps
    if bps == int(bps):
        bps_str = f"{int(bps)} BPS"
    else:
        bps_str = f"{bps:.6f}".rstrip('0').rstrip('.') + " BPS"

    if block_time_sec >= 1.0:
        sec_str = f"{block_time_sec:.6f}".rstrip('0').rstrip('.')
        return f"{bps_str} ({sec_str}s block time)"
    else:
        ms = round(block_time_sec * 1000)
        return f"{bps_str} ({ms}ms block time)"


def _run_mode_1_calculate_k():
    print("\n" + "=" * 80)
    print("MODE 1: CALCULATE GHOSTDAG k & ANTICONE EXPECTATION")
    print("=" * 80)

    bps = _prompt_bps_or_blocktime()
    delay = _prompt_float("Enter Max Network Delay (D) in seconds", default_val=5.0)
    delta = _prompt_float("Enter Target Tail Delta (δ)", default_val=0.01)

    x = calculate_anticone_size_expectation(bps, delay)
    k = calculate_ghostdag_k(x, delta)

    dist = calculate_ghostdag_k_with_probability_distribution(x, delta)
    actual_tail = 1.0 - sum(dist)

    print("\n" + "-" * 80)
    print("GHOSTDAG PARAMETERIZATION RESULTS")
    print("-" * 80)
    print("Configured Parameters:")
    print(f"  • Target Block Rate (λ)   : {_format_rate_or_duration(bps)}")
    print(f"  • Max Network Delay (D)   : {delay}s ({round(delay * 1000)}ms)")
    print(f"  • Target Tail Delta (δ)   : {delta} ({delta * 100:.2f}%)")
    print(f"  • Round-Trip Factor       : 2 (2Dλ formula)")
    print("\nDerived Outputs:")
    print(f"  • Expected Anticone Size  : {x:.6f}".rstrip('0').rstrip('.'))
    print(f"  • Minimal GHOSTDAG k      : {k}")
    print(f"  • Actual Tail Probability : {actual_tail:.6%}")
    print("-" * 80)


def _run_mode_2_concurrency_distribution():
    print("\n" + "=" * 80)
    print("MODE 2: DAG CONCURRENCY PROBABILITY DISTRIBUTION")
    print("=" * 80)

    bps = _prompt_bps_or_blocktime()
    actual_delay = _prompt_float("Enter Actual Network Delay (D) in seconds", default_val=5.0)
    delta = _prompt_float("Enter Tail Delta Cutoff (δ)", default_val=0.01)

    x = calculate_anticone_size_expectation(bps, actual_delay)
    distribution = calculate_ghostdag_k_with_probability_distribution(x, delta)

    print("\n" + "-" * 80)
    print("DAG CONCURRENCY PROBABILITY DISTRIBUTION")
    print("-" * 80)
    print("Configured Parameters:")
    print(f"  • Target Block Rate (λ)   : {_format_rate_or_duration(bps)}")
    print(f"  • Actual Network Delay (D): {actual_delay}s ({round(actual_delay * 1000)}ms)")
    print(f"  • Round-Trip Factor       : 2 (2Dλ formula)")
    print(f"  • Expected Anticone (x)   : {x:.6f}".rstrip('0').rstrip('.'))
    print("\n" + f"{'Anticone Size (n)':<20} {'P(Anticone = n)':<20} {'Cumulative P(<= n)':<20}")
    print("-" * 80)

    cum_prob = 0.0
    for n, prob in enumerate(distribution):
        cum_prob += prob
        print(f"n = {n:<16d} {prob:<19.6%} {cum_prob:<19.6%}")

    print("-" * 80)
    print("Distribution Summary:")
    print(f"  • Calculated Terms          : n = 0 through {len(distribution) - 1}")
    print(f"  • Total Calculated Coverage : {cum_prob:.6%}")
    print(f"  • Remaining Tail P(> {len(distribution) - 1})   : {1.0 - cum_prob:.6%}")
    print("-" * 80)


def _run_mode_3_bounds_for_k():
    print("\n" + "=" * 80)
    print("MODE 3: BLOCK TIME BOUNDS FOR TARGET k (k = 1 to 18)")
    print("=" * 80)

    while True:
        raw = input("Enter Target k parameter [1 - 18, default: 10]: ").strip()
        if not raw:
            k_target = 10
            break
        try:
            k_target = int(raw)
            if 1 <= k_target <= 18:
                break
            print("Error: k must be an integer between 1 and 18.")
        except ValueError:
            print("Error: Please enter a valid integer.")

    min_ms, max_ms = block_time_ms_bounds_for_k(k_target)

    print("\n" + "-" * 80)
    print(f"BLOCK TIME BOUNDS FOR k = {k_target}")
    print("-" * 80)
    print("Baseline Fixed Assumptions:")
    print("  • Max Network Delay (D)   : 5s (5000ms)")
    print("  • Target Tail Delta (δ)   : 0.01 (1%)")
    print("  • Quantization Precision  : 1ms")
    print(f"\nDerived Bounds for k = {k_target}:")
    print(f"  • Minimum Block Time      : {format_duration(min_ms)} ({min_ms}ms | ~{1000.0 / min_ms:.4f} BPS)")
    print(f"  • Maximum Block Time      : {format_duration(max_ms)} ({max_ms}ms | ~{1000.0 / max_ms:.4f} BPS)")
    print(f"  • Inclusive Valid Range   : [{min_ms}ms, {max_ms}ms]")
    print("-" * 80)


def main_menu():
    import sys
    while True:
        print("\n" + "=" * 80)
        print("                      GHOSTDAG Parameter Explorer")
        print("=" * 80)
        print("Default Baseline Assumptions:")
        print("  • Max Network Delay (D) : 5s (5000ms)")
        print("  • Target Tail Delta (δ) : 0.01 (1% tail bound)")
        print("\nSelect an option:")
        print("  [1] Calculate GHOSTDAG k")
        print("      (Derive k and expected anticone size from Block Rate or Block Time)")
        print("  [2] DAG Concurrency Distribution P(n)")
        print("      (Explore anticone concurrency & DAG structure for a given Actual Delay)")
        print("  [3] Block Time Range Bounds for Target k (k = 1 to 18)")
        print("      (Find precise min/max ms block times that yield a specific k)")
        print("\n  [0] Exit")

        choice = input("\nSelect an option [0-3]: ").strip()

        if choice == "1":
            _run_mode_1_calculate_k()
        elif choice == "2":
            _run_mode_2_concurrency_distribution()
        elif choice == "3":
            _run_mode_3_bounds_for_k()
        elif choice == "0":
            print("\nExiting GHOSTDAG Parameter Explorer. Goodbye!")
            sys.exit(0)
        else:
            print("\nInvalid selection. Please enter a number between 0 and 3.")

        input("\nPress Enter to return to the main menu...")


if __name__ == "__main__":
    main_menu()
