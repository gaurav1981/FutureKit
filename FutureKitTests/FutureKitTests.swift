//
//  FutureKitTests.swift
//  FutureKitTests
//
//  Created by Michael Gray on 4/12/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import UIKit
import XCTest
import FutureKit


let executor = Executor.createConcurrentQueue(label: "FuturekitTests")
let executor2 = Executor.createConcurrentQueue(label: "FuturekitTests2")



let opQueue = { () -> Executor in
    let opqueue = NSOperationQueue()
    opqueue.maxConcurrentOperationCount = 5
    return Executor.OperationQueue(opqueue)
    }()
    

func dumbAdd(x : Int, y: Int) -> Future<Int> {
    let p = Promise<Int>()
    
    executor2.execute { () -> Void in
        let z = x + y
        p.completeWithSuccess(z)
    }
    return p.future
}

func dumbJob() -> Future<Int> {
    return dumbAdd(0, 1)
}

func divideAndConquer(x: Int, y: Int,iterationsDesired : Int) -> Future<Int> // returns iterations done
{
    let p = Promise<Int>()
    
    executor.execute { () -> Void in
    
        var subFutures : [Future<Int>] = []
        
        if (iterationsDesired == 1) {
            subFutures.append(dumbAdd(x,y))
        }
        else {
            let half = iterationsDesired / 2
            subFutures.append(divideAndConquer(x,y,half))
            subFutures.append(divideAndConquer(x,y,half))
            if ((half * 2)  < iterationsDesired) {
                subFutures.append(dumbJob())
            }
        }
        
        let all = sequenceFutures(subFutures)
        
        all.onSuccess({ (result) -> Void in
            var sum = 0
            for i in result {
                sum += i
            }
            p.completeWithSuccess(sum)
        })
    }
    return p.future
}


extension Future {
    
    func expectationTestFor(testcase: XCTestCase, _ description : String,
        assertion : ((completion : Completion<T>) -> (assert:BooleanType,message:String)),
        file: String = __FILE__,
        line: UInt = __LINE__
        ) -> XCTestExpectation! {
            
            let e = testcase.expectationWithDescription(description)
            
            self.onComplete { (completion) -> Void in
                let test = assertion(completion:completion)
                
                XCTAssert(test.assert,test.message,file:file,line:line)
                e.fulfill()
            }
            return e
    }
    
    
    func expectationTestFor(testcase: XCTestCase, _ description : String,
        test : ((result:T) -> BooleanType)) -> XCTestExpectation! {
            
            return self.expectationTestFor(testcase, description, assertion: { (completion : Completion<T>) -> (assert: BooleanType, message: String) in
                switch completion.state {
                case .Success:
                    let result = completion.result
                    return (test(result: result),"test result failure for Future with result \(result)" )
                case let .Fail:
                    let e = completion.error
                    return (false,"Future Failed with \(e) \(e.localizedDescription)" )
                case .Cancelled:
                    return (false,"Future Cancelled" )
                }
                })
    }
    
    func expectationTestFor(testcase: XCTestCase, _  description : String,
        file: String = __FILE__,
        line: UInt = __LINE__
        ) -> XCTestExpectation! {
            
            return self.expectationTestFor(testcase, description, assertion: { (completion : Completion<T>) -> (assert: BooleanType, message: String) in
                switch completion.state {
                case .Success:
                    return (true, "")
                case .Fail:
                    let e = completion.error
                    return (false,"Future Failed with \(e) \(e.localizedDescription)" )
                case .Cancelled:
                    return (false,"Future Cancelled" )
                }
                }, file:file, line:line)
    }


    
}


class FutureKitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // serialQueueDispatchPool.flushQueue(keepCapacity: false)
        // concurrentQueueDispatchPool.flushQueue(keepCapacity: false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testFuture() {
        let x = Future<Int>(success: 5)
        
        XCTAssert(x.completion!.result == 5, "it works")
    }
    func testFutureWait() {
        let f = dumbAdd(1, 1).waitUntilCompleted()

        XCTAssert(f.result == 2, "it works")
    }
    
    func doATestCaseSync(x : Int, y: Int, iterations : Int) {
        let f = divideAndConquer(x,y,iterations).waitUntilCompleted()
        
        let expectedResult = (x+y)*iterations
        XCTAssert(f.result == expectedResult, "it works")
        
    }
    
    func testADoneFutureExpectation() {
        let val = 5
        
        let f = Future<Int>(success: val)
        var ex = f.expectationTestFor(self, "AsyncMadness") { (result) -> BooleanType in
            return (result == val)
        }
        
        self.waitForExpectationsWithTimeout(30.0, handler: nil)
        
        
    }

    func doATestCase(x : Int, y: Int, iterations : Int) {
        
        
        let f = divideAndConquer(x,y,iterations)
        
        var ex = f.expectationTestFor(self, "Description") { (result) -> BooleanType in
            return (result == (x+y)*iterations)
        }
        
        self.waitForExpectationsWithTimeout(30.0, handler: nil)
        
    }
    
    let million = 20000
    
    func testMillionWithBarrierConcurrent() {
        FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY = .BarrierConcurrent
        
        self.measureBlock() {
            self.doATestCase(0, y: 1, iterations: self.million)
        }
    }

    
/*    func testMillionWithBarrierSerial() {
        FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY = .BarrierSerial
        
        self.measureBlock() {
            self.doATestCase(0, y: 1, iterations: self.million)
        }
    } */
    
    func testMillionWithSerialQueue() {
        FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY = .SerialQueue
        
        self.measureBlock() {
            self.doATestCase(0, y: 1, iterations: self.million)
        }
    }
    func testMillionWithNSObjectLock() {
        FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY = .NSObjectLock
        
        self.measureBlock() {
            self.doATestCase(0, y: 1, iterations: self.million)
        }
    }
    
    func testMillionWithNSLock() {
        FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY = .NSLock
        
        self.measureBlock() {
            self.doATestCase(0, y: 1, iterations: self.million)
        }
    }

    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }
    
}