//===- PassManager internal APIs and implementation details -----*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
/// \file
///
/// This header provides internal APIs and implementation details used by the
/// pass management interfaces exposed in PassManager.h. To understand more
/// context of why these particular interfaces are needed, see that header
/// file. None of these APIs should be used elsewhere.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_PASSMANAGERINTERNAL_H
#define LLVM_IR_PASSMANAGERINTERNAL_H

#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringRef.h"

namespace llvm {

template <typename IRUnitT, typename... ExtraArgTs> class AnalysisManager;
class PreservedAnalyses;

/// \brief Implementation details of the pass manager interfaces.
namespace detail {

/// \brief Template for the abstract base class used to dispatch
/// polymorphically over pass objects.
template <typename IRUnitT, typename AnalysisManagerT, typename... ExtraArgTs>
struct PassConcept {
  // Boiler plate necessary for the container of derived classes.
  virtual ~PassConcept() {}

  /// \brief The polymorphic API which runs the pass over a given IR entity.
  ///
  /// Note that actual pass object can omit the analysis manager argument if
  /// desired. Also that the analysis manager may be null if there is no
  /// analysis manager in the pass pipeline.
  virtual PreservedAnalyses run(IRUnitT &IR, AnalysisManagerT &AM,
                                ExtraArgTs... ExtraArgs) = 0;

  /// \brief Polymorphic method to access the name of a pass.
  virtual StringRef name() = 0;
};

/// \brief A template wrapper used to implement the polymorphic API.
///
/// Can be instantiated for any object which provides a \c run method accepting
/// an \c IRUnitT& and an \c AnalysisManager<IRUnit>&. It requires the pass to
/// be a copyable object.
template <typename IRUnitT, typename PassT, typename PreservedAnalysesT,
          typename AnalysisManagerT, typename... ExtraArgTs>
struct PassModel : PassConcept<IRUnitT, AnalysisManagerT, ExtraArgTs...> {
  explicit PassModel(PassT Pass) : Pass(std::move(Pass)) {}
  // We have to explicitly define all the special member functions because MSVC
  // refuses to generate them.
  PassModel(const PassModel &Arg) : Pass(Arg.Pass) {}
  PassModel(PassModel &&Arg) : Pass(std::move(Arg.Pass)) {}
  friend void swap(PassModel &LHS, PassModel &RHS) {
    using std::swap;
    swap(LHS.Pass, RHS.Pass);
  }
  PassModel &operator=(PassModel RHS) {
    swap(*this, RHS);
    return *this;
  }

  PreservedAnalysesT run(IRUnitT &IR, AnalysisManagerT &AM,
                         ExtraArgTs... ExtraArgs) override {
    return Pass.run(IR, AM, ExtraArgs...);
  }
  StringRef name() override { return PassT::name(); }
  PassT Pass;
};

/// \brief Abstract concept of an analysis result.
///
/// This concept is parameterized over the IR unit that this result pertains
/// to.
template <typename IRUnitT> struct AnalysisResultConcept {
  virtual ~AnalysisResultConcept() {}

  /// \brief Method to try and mark a result as invalid.
  ///
  /// When the outer analysis manager detects a change in some underlying
  /// unit of the IR, it will call this method on all of the results cached.
  ///
  /// This method also receives a set of preserved analyses which can be used
  /// to avoid invalidation because the pass which changed the underlying IR
  /// took care to update or preserve the analysis result in some way.
  ///
  /// \returns true if the result is indeed invalid (the default).
  virtual bool invalidate(IRUnitT &IR, const PreservedAnalyses &PA) = 0;
};

/// \brief SFINAE metafunction for computing whether \c ResultT provides an
/// \c invalidate member function.
template <typename IRUnitT, typename ResultT> class ResultHasInvalidateMethod {
  typedef char EnabledType;
  struct DisabledType {
    char a, b;
  };

  // Purely to help out MSVC which fails to disable the below specialization,
  // explicitly enable using the result type's invalidate routine if we can
  // successfully call that routine.
  template <typename T> struct Nonce { typedef EnabledType Type; };
  template <typename T>
  static typename Nonce<decltype(std::declval<T>().invalidate(
      std::declval<IRUnitT &>(), std::declval<PreservedAnalyses>()))>::Type
      check(rank<2>);

  // First we define an overload that can only be taken if there is no
  // invalidate member. We do this by taking the address of an invalidate
  // member in an adjacent base class of a derived class. This would be
  // ambiguous if there were an invalidate member in the result type.
  template <typename T, typename U> static DisabledType NonceFunction(T U::*);
  struct CheckerBase { int invalidate; };
  template <typename T> struct Checker : CheckerBase, T {};
  template <typename T>
  static decltype(NonceFunction(&Checker<T>::invalidate)) check(rank<1>);

  // Now we have the fallback that will only be reached when there is an
  // invalidate member, and enables the trait.
  template <typename T>
  static EnabledType check(rank<0>);

public:
  enum { Value = sizeof(check<ResultT>(rank<2>())) == sizeof(EnabledType) };
};

/// \brief Wrapper to model the analysis result concept.
///
/// By default, this will implement the invalidate method with a trivial
/// implementation so that the actual analysis result doesn't need to provide
/// an invalidation handler. It is only selected when the invalidation handler
/// is not part of the ResultT's interface.
template <typename IRUnitT, typename PassT, typename ResultT,
          typename PreservedAnalysesT = PreservedAnalyses,
          bool HasInvalidateHandler =
              ResultHasInvalidateMethod<IRUnitT, ResultT>::Value>
struct AnalysisResultModel;

/// \brief Specialization of \c AnalysisResultModel which provides the default
/// invalidate functionality.
template <typename IRUnitT, typename PassT, typename ResultT,
          typename PreservedAnalysesT>
struct AnalysisResultModel<IRUnitT, PassT, ResultT, PreservedAnalysesT, false>
    : AnalysisResultConcept<IRUnitT> {
  explicit AnalysisResultModel(ResultT Result) : Result(std::move(Result)) {}
  // We have to explicitly define all the special member functions because MSVC
  // refuses to generate them.
  AnalysisResultModel(const AnalysisResultModel &Arg) : Result(Arg.Result) {}
  AnalysisResultModel(AnalysisResultModel &&Arg)
      : Result(std::move(Arg.Result)) {}
  friend void swap(AnalysisResultModel &LHS, AnalysisResultModel &RHS) {
    using std::swap;
    swap(LHS.Result, RHS.Result);
  }
  AnalysisResultModel &operator=(AnalysisResultModel RHS) {
    swap(*this, RHS);
    return *this;
  }

  /// \brief The model bases invalidation solely on being in the preserved set.
  //
  // FIXME: We should actually use two different concepts for analysis results
  // rather than two different models, and avoid the indirect function call for
  // ones that use the trivial behavior.
  bool invalidate(IRUnitT &, const PreservedAnalysesT &PA) override {
    return !PA.preserved(PassT::ID());
  }

  ResultT Result;
};

/// \brief Specialization of \c AnalysisResultModel which delegates invalidate
/// handling to \c ResultT.
template <typename IRUnitT, typename PassT, typename ResultT,
          typename PreservedAnalysesT>
struct AnalysisResultModel<IRUnitT, PassT, ResultT, PreservedAnalysesT, true>
    : AnalysisResultConcept<IRUnitT> {
  explicit AnalysisResultModel(ResultT Result) : Result(std::move(Result)) {}
  // We have to explicitly define all the special member functions because MSVC
  // refuses to generate them.
  AnalysisResultModel(const AnalysisResultModel &Arg) : Result(Arg.Result) {}
  AnalysisResultModel(AnalysisResultModel &&Arg)
      : Result(std::move(Arg.Result)) {}
  friend void swap(AnalysisResultModel &LHS, AnalysisResultModel &RHS) {
    using std::swap;
    swap(LHS.Result, RHS.Result);
  }
  AnalysisResultModel &operator=(AnalysisResultModel RHS) {
    swap(*this, RHS);
    return *this;
  }

  /// \brief The model delegates to the \c ResultT method.
  bool invalidate(IRUnitT &IR, const PreservedAnalysesT &PA) override {
    return Result.invalidate(IR, PA);
  }

  ResultT Result;
};

/// \brief Abstract concept of an analysis pass.
///
/// This concept is parameterized over the IR unit that it can run over and
/// produce an analysis result.
template <typename IRUnitT, typename... ExtraArgTs> struct AnalysisPassConcept {
  virtual ~AnalysisPassConcept() {}

  /// \brief Method to run this analysis over a unit of IR.
  /// \returns A unique_ptr to the analysis result object to be queried by
  /// users.
  virtual std::unique_ptr<AnalysisResultConcept<IRUnitT>>
  run(IRUnitT &IR, AnalysisManager<IRUnitT, ExtraArgTs...> &AM,
      ExtraArgTs... ExtraArgs) = 0;

  /// \brief Polymorphic method to access the name of a pass.
  virtual StringRef name() = 0;
};

/// \brief Wrapper to model the analysis pass concept.
///
/// Can wrap any type which implements a suitable \c run method. The method
/// must accept an \c IRUnitT& and an \c AnalysisManager<IRUnitT>& as arguments
/// and produce an object which can be wrapped in a \c AnalysisResultModel.
template <typename IRUnitT, typename PassT, typename... ExtraArgTs>
struct AnalysisPassModel : AnalysisPassConcept<IRUnitT, ExtraArgTs...> {
  explicit AnalysisPassModel(PassT Pass) : Pass(std::move(Pass)) {}
  // We have to explicitly define all the special member functions because MSVC
  // refuses to generate them.
  AnalysisPassModel(const AnalysisPassModel &Arg) : Pass(Arg.Pass) {}
  AnalysisPassModel(AnalysisPassModel &&Arg) : Pass(std::move(Arg.Pass)) {}
  friend void swap(AnalysisPassModel &LHS, AnalysisPassModel &RHS) {
    using std::swap;
    swap(LHS.Pass, RHS.Pass);
  }
  AnalysisPassModel &operator=(AnalysisPassModel RHS) {
    swap(*this, RHS);
    return *this;
  }

  // FIXME: Replace PassT::Result with type traits when we use C++11.
  typedef AnalysisResultModel<IRUnitT, PassT, typename PassT::Result>
      ResultModelT;

  /// \brief The model delegates to the \c PassT::run method.
  ///
  /// The return is wrapped in an \c AnalysisResultModel.
  std::unique_ptr<AnalysisResultConcept<IRUnitT>>
  run(IRUnitT &IR, AnalysisManager<IRUnitT, ExtraArgTs...> &AM,
      ExtraArgTs... ExtraArgs) override {
    return make_unique<ResultModelT>(Pass.run(IR, AM, ExtraArgs...));
  }

  /// \brief The model delegates to a static \c PassT::name method.
  ///
  /// The returned string ref must point to constant immutable data!
  StringRef name() override { return PassT::name(); }

  PassT Pass;
};

} // End namespace detail
}

#endif
