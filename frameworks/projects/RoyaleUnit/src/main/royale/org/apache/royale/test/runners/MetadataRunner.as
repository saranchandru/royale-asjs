////////////////////////////////////////////////////////////////////////////////
//
//  Licensed to the Apache Software Foundation (ASF) under one or more
//  contributor license agreements.  See the NOTICE file distributed with
//  this work for additional information regarding copyright ownership.
//  The ASF licenses this file to You under the Apache License, Version 2.0
//  (the "License"); you may not use this file except in compliance with
//  the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////
package org.apache.royale.test.runners
{
	import org.apache.royale.events.Event;
	import org.apache.royale.reflection.MetaDataDefinition;
	import org.apache.royale.reflection.MethodDefinition;
	import org.apache.royale.reflection.TypeDefinition;
	import org.apache.royale.reflection.describeType;
	import org.apache.royale.reflection.getQualifiedClassName;
	import org.apache.royale.test.AssertionError;
	import org.apache.royale.test.runners.notification.Failure;
	import org.apache.royale.test.runners.notification.IRunListener;
	import org.apache.royale.test.runners.notification.IRunNotifier;
	import org.apache.royale.test.runners.notification.Result;
	import org.apache.royale.utils.Timer;

	/**
	 * Runs a class containing methods marked with <code>[Test]</code> metadata.
	 * 
	 * <p>Also supports the following optional metadata:</p>
	 * 
	 * <ul>
	 * <li>Tests with <code>[Ignore]</code> metdata should be ignored (skipped).</li>
	 * <li>Methods with <code>[Before]</code> metadata are run before every individual test.</li>
	 * <li>Methods with <code>[After]</code> metadata are run after every individual test.</li>
	 * <li>Methods with <code>[BeforeClass]</code> metadata are run one time, before the first test.</li>
	 * <li>Methods with <code>[AfterClass]</code> metadata are run one time, after the final test.</li>
	 * </ul>
	 */
	public class MetadataRunner implements ITestRunner
	{
		/**
		 * The default timeout, measured in milliseconds, before an asynchronous
		 * test should be considered a failure.
		 */
		public static const DEFAULT_ASYNC_TIMEOUT:int = 500;

		/**
		 * Constructor.
		 */
		public function MetadataRunner(testClass:Class)
		{
			super();
			if(!testClass)
			{
				throw new Error("Test class must not be null.");
			}
			_testClass = testClass;
		}

		/**
		 * @private
		 */
		public function get description():String
		{
			return getQualifiedClassName(_testClass);
		}

		/**
		 * @private
		 */
		protected var _testClass:Class = null;

		/**
		 * @private
		 */
		protected var _failures:Boolean = false;

		/**
		 * @private
		 */
		protected var _stopRequested:Boolean = false;

		/**
		 * @private
		 */
		protected var _notifier:IRunNotifier = null;

		/**
		 * @private
		 */
		protected var _listener:IRunListener = null;

		/**
		 * @private
		 */
		protected var _collectedTests:Vector.<TestInfo> = new <TestInfo>[];

		/**
		 * @private
		 */
		protected var _currentIndex:int = 0;

		/**
		 * @private
		 */
		protected var _target:Object = null;

		/**
		 * @private
		 */
		protected var _result:Result = null;

		/**
		 * @private
		 */
		protected var _before:Function = null;

		/**
		 * @private
		 */
		protected var _after:Function = null;

		/**
		 * @private
		 */
		protected var _beforeClass:Function = null;

		/**
		 * @private
		 */
		protected var _afterClass:Function = null;

		/**
		 * @private
		 */
		protected var _timer:Timer = null;

		/**
		 * @inheritDoc
		 */
		public function pleaseStop():void
		{
			_stopRequested = true;
		}

		/**
		 * @inheritDoc
		 */
		public function run(notifier:IRunNotifier):void
		{
			_notifier = notifier;
			_failures = false;
			_stopRequested = false;
			_result = new Result();
			_listener = _result.createListener();
			_notifier.addListener(_listener);

			_notifier.fireTestRunStarted(description);
			if(_testClass)
			{
				_target = new _testClass();
				readMetadataTags();
				continueAll();
			}
			else
			{
				_failures = true;
				_notifier.fireTestFailure(new Failure(description + ".initializationError", new Error("No tests specified.")));

				_notifier.removeListener(_listener);
				_notifier.fireTestRunFinished(_result);
			}
		}

		/**
		 * @private
		 */
		protected function checkForDone():Boolean
		{
			var done:Boolean = _currentIndex >= _collectedTests.length;
			if(!done)
			{
				return false;
			}
			if(_afterClass !== null)
			{
				_afterClass.apply(_target);
			}
			_notifier.removeListener(_listener);
			_notifier.fireTestRunFinished(_result);
			return true;
		}

		/**
		 * @private
		 */
		protected function continueAll():void
		{
			var sync:Boolean = true;
			while(sync && !checkForDone())
			{
				sync = continueNext();
			}
		}

		/**
		 * @private
		 */
		protected function continueNext():Boolean
		{
			if(_currentIndex == 0 && _beforeClass !== null)
			{
				_beforeClass.apply(_target);
			}
			var test:TestInfo = _collectedTests[_currentIndex];
			try
			{
				if(test.ignore)
				{
					_notifier.fireTestIgnored(test.description);
					_currentIndex++;
					return true;
				}
				_notifier.fireTestStarted(test.description);
				if(_before !== null)
				{
					_before.apply(_target);
				}
				test.reference.apply(_target);
				if(test.async)
				{
					var timeout:int = getTimeout(test);
					_timer = new Timer(timeout, 1);
					_timer.addEventListener(Timer.TIMER, timer_timerHandler);
					return false;
				}
			}
			catch(error:Error)
			{
				_failures = true;
				_notifier.fireTestFailure(new Failure(test.description, error));
			}
			afterTest(test);
			return true;
		}

		protected function afterTest(test:TestInfo):void
		{
			try
			{
				if(_after !== null)
				{
					_after.apply(_target);
				}
			}
			catch(error:Error)
			{
				_failures = true;
				_notifier.fireTestFailure(new Failure(test.description, error));
			}
			_notifier.fireTestFinished(test.description);
			_currentIndex++;
		}

		/**
		 * @private
		 */
		protected function readMetadataTags():void
		{
			collectTests();
			if(_collectedTests.length === 0)
			{
				throw new Error("No methods found with [Test] metadata. Did you forget to include the -keep-as3-metadata compiler option?")
			}
			_beforeClass = collectMethodWithMetadataTag(TestMetadata.BEFORE_CLASS);
			_afterClass = collectMethodWithMetadataTag(TestMetadata.AFTER_CLASS);
			_before = collectMethodWithMetadataTag(TestMetadata.BEFORE);
			_after = collectMethodWithMetadataTag(TestMetadata.AFTER);
		}

		/**
		 * @private
		 */
		protected function collectMethodWithMetadataTag(tagName:String):Function
		{
			var typeDefinition:TypeDefinition = describeType(_target);
			if(!typeDefinition)
			{
				return null;
			}
			var methods:Array = typeDefinition.methods;
			var length:int = methods.length;
			for(var i:int = 0; i < length; i++)
			{
				var method:MethodDefinition = methods[i];
				var metadata:Array = method.retrieveMetaDataByName(tagName);
				if(metadata.length > 0)
				{
					return _target[method.name];
				}
			}
			return null;
		}

		/**
		 * @private
		 */
		protected function collectTests():void
		{
			_collectedTests.length = 0;
			_currentIndex = 0;

			var typeDefinition:TypeDefinition = describeType(_target);
			if(!typeDefinition)
			{
				return;
			}

			var methods:Array = typeDefinition.methods;
			var length:int = methods.length;
			for(var i:int = 0; i < length; i++)
			{
				var method:MethodDefinition = methods[i];
				var testName:String = null;
				var testFunction:Function = null;
				var ignore:Boolean = false;
				var async:Boolean = false;

				var testMetadata:Array = method.retrieveMetaDataByName(TestMetadata.TEST);
				if(testMetadata.length > 0)
				{
					var testTag:MetaDataDefinition = testMetadata[0];
					var qualifiedName:String = typeDefinition.qualifiedName;
					var qualifiedNameParts:Array = qualifiedName.split(".");
					var lastPart:String = qualifiedNameParts.pop();
					qualifiedName = qualifiedNameParts.join(".");
					if(qualifiedName.length > 0)
					{
						qualifiedName += "::";
					}
					qualifiedName += lastPart;
					testName = qualifiedName + "." + method.name;
					testFunction = _target[method.name];
					async = testTag.getArgsByKey("async").length > 0;
				}
				var ignoreMetadata:Array = method.retrieveMetaDataByName(TestMetadata.IGNORE);
				if(ignoreMetadata.length > 0)
				{
					ignore = true;
				}
				if(testName !== null)
				{
					_collectedTests.push(new TestInfo(testName, testFunction, ignore, async));
				}
			}
		}

		/**
		 * @private
		 */
		protected function getTimeout(test:TestInfo):int
		{
			return DEFAULT_ASYNC_TIMEOUT;
		}

		/**
		 * @private
		 */
		protected function cleanupTimer():void
		{
			_timer.removeAllListeners();
			_timer = null;
		}

		/**
		 * @private
		 */
		protected function timer_timerHandler(event:Event):void
		{
			cleanupTimer();

			var test:TestInfo = _collectedTests[_currentIndex];
			var timeout:int = getTimeout(test);
			_failures = true;
			_notifier.fireTestFailure(new Failure(test.description, new AssertionError("Test did not complete within specified timeout " + timeout + "ms")));
			
			_notifier.fireTestFinished(test.description);
			_currentIndex++;

			continueAll();
		}
	}
}

class TestInfo
{
	public function TestInfo(name:String, reference:Function, ignore:Boolean, async:Boolean)
	{
		this.description = name;
		this.reference = reference;
		this.ignore = ignore;
		this.async = async;
	}

	public var description:String;
	public var reference:Function;
	public var ignore:Boolean;
	public var async:Boolean;
}