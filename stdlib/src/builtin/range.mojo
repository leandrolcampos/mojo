# ===----------------------------------------------------------------------=== #
# Copyright (c) 2024, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #
"""Implements a 'range' call.

These are Mojo built-ins, so you don't need to import them.
"""


from python import PythonObject

# ===----------------------------------------------------------------------=== #
# Utilities
# ===----------------------------------------------------------------------=== #


@always_inline
fn _div_ceil_positive(numerator: Int, denominator: Int) -> Int:
    """Divides an integer by another integer, and round up to the nearest
    integer.

    Constraints:
      Will raise an exception if denominator is zero.
      Assumes that both inputs are positive.

    Args:
      numerator: The numerator.
      denominator: The denominator.

    Returns:
      The ceiling of numerator divided by denominator.
    """
    debug_assert(denominator != 0, "divide by zero")
    return (numerator + denominator - 1)._positive_div(denominator)


@always_inline
fn _abs(x: Int) -> Int:
    return x if x > 0 else -x


@always_inline
fn _sign(x: Int) -> Int:
    if x > 0:
        return 1
    if x < 0:
        return -1
    return 0


@always_inline
fn _max(a: Int, b: Int) -> Int:
    return a if a > b else b


# ===----------------------------------------------------------------------=== #
# Range
# ===----------------------------------------------------------------------=== #


@register_passable("trivial")
struct _ZeroStartingRange(Sized, ReversibleRange):
    var curr: Int
    var end: Int

    @always_inline("nodebug")
    fn __init__(inout self, end: Int):
        self.curr = _max(0, end)
        self.end = end

    @always_inline("nodebug")
    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __next__(inout self) -> Int:
        var curr = self.curr
        self.curr -= 1
        return self.end - curr

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        return self.curr

    @always_inline("nodebug")
    fn __getitem__(self, idx: Int) -> Int:
        return idx

    @always_inline("nodebug")
    fn __reversed__(self) -> _StridedRangeIterator:
        return _StridedRangeIterator(self.end - 1, -1, -1)


@value
@register_passable("trivial")
struct _SequentialRange(Sized, ReversibleRange):
    var start: Int
    var end: Int

    @always_inline("nodebug")
    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __next__(inout self) -> Int:
        var start = self.start
        self.start += 1
        return start

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        # FIXME(#38392):
        # return _max(0, self.end - self.start)
        return self.end - self.start if self.start < self.end else 0

    @always_inline("nodebug")
    fn __getitem__(self, idx: Int) -> Int:
        return self.start + idx

    @always_inline("nodebug")
    fn __reversed__(self) -> _StridedRangeIterator:
        return _StridedRangeIterator(self.end - 1, self.start - 1, -1)


@value
@register_passable("trivial")
struct _StridedRangeIterator(Sized):
    var start: Int
    var end: Int
    var step: Int

    @always_inline("nodebug")
    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __len__(self) -> Int:
        if self.step > 0 and self.start < self.end:
            return self.end - self.start
        elif self.step < 0 and self.start > self.end:
            return self.start - self.end
        else:
            return 0

    @always_inline
    fn __next__(inout self) -> Int:
        var result = self.start
        self.start += self.step
        return result


@value
@register_passable("trivial")
struct _StridedRange(Sized, ReversibleRange):
    var start: Int
    var end: Int
    var step: Int

    @always_inline("nodebug")
    fn __init__(inout self, end: Int):
        self.start = 0
        self.end = end
        self.step = 1

    @always_inline("nodebug")
    fn __init__(inout self, start: Int, end: Int):
        self.start = start
        self.end = end
        self.step = 1

    @always_inline("nodebug")
    fn __iter__(self) -> _StridedRangeIterator:
        return _StridedRangeIterator(self.start, self.end, self.step)

    @always_inline
    fn __next__(inout self) -> Int:
        var result = self.start
        self.start += self.step
        return result

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        # FIXME(#38392)
        # if (self.step > 0) == (self.start > self.end):
        #     return 0
        return _div_ceil_positive(_abs(self.start - self.end), _abs(self.step))

    @always_inline("nodebug")
    fn __getitem__(self, idx: Int) -> Int:
        return self.start + idx * self.step

    @always_inline("nodebug")
    fn __reversed__(self) -> _StridedRangeIterator:
        var shifted_end = self.end - _sign(self.step)
        var start = shifted_end - ((shifted_end - self.start) % self.step)
        var end = self.start - self.step
        var step = -self.step
        return _StridedRangeIterator(start, end, step)


@always_inline("nodebug")
fn range[type: Intable](end: type) -> _ZeroStartingRange:
    """Constructs a [0; end) Range.

    Parameters:
        type: The type of the end value.

    Args:
        end: The end of the range.

    Returns:
        The constructed range.
    """
    return _ZeroStartingRange(int(end))


@always_inline
fn range[type: IntableRaising](end: type) raises -> _ZeroStartingRange:
    """Constructs a [0; end) Range.

    Parameters:
        type: The type of the end value.

    Args:
        end: The end of the range.

    Returns:
        The constructed range.
    """
    return _ZeroStartingRange(int(end))


@always_inline("nodebug")
fn range[t0: Intable, t1: Intable](start: t0, end: t1) -> _SequentialRange:
    """Constructs a [start; end) Range.

    Parameters:
        t0: The type of the start value.
        t1: The type of the end value.

    Args:
        start: The start of the range.
        end: The end of the range.

    Returns:
        The constructed range.
    """
    return _SequentialRange(int(start), int(end))


@always_inline("nodebug")
fn range[
    t0: IntableRaising, t1: IntableRaising
](start: t0, end: t1) raises -> _SequentialRange:
    """Constructs a [start; end) Range.

    Parameters:
        t0: The type of the start value.
        t1: The type of the end value.

    Args:
        start: The start of the range.
        end: The end of the range.

    Returns:
        The constructed range.
    """
    return _SequentialRange(int(start), int(end))


@always_inline
fn range[
    t0: Intable, t1: Intable, t2: Intable
](start: t0, end: t1, step: t2) -> _StridedRange:
    """Constructs a [start; end) Range with a given step.

    Parameters:
        t0: The type of the start value.
        t1: The type of the end value.
        t2: The type of the step value.

    Args:
        start: The start of the range.
        end: The end of the range.
        step: The step for the range.

    Returns:
        The constructed range.
    """
    return _StridedRange(int(start), int(end), int(step))


@always_inline
fn range[
    t0: IntableRaising, t1: IntableRaising, t2: IntableRaising
](start: t0, end: t1, step: t2) raises -> _StridedRange:
    """Constructs a [start; end) Range with a given step.

    Parameters:
        t0: The type of the start value.
        t1: The type of the end value.
        t2: The type of the step value.

    Args:
        start: The start of the range.
        end: The end of the range.
        step: The step for the range.

    Returns:
        The constructed range.
    """
    return _StridedRange(int(start), int(end), int(step))
