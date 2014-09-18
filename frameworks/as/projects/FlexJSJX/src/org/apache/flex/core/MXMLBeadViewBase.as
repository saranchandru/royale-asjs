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
package org.apache.flex.core
{
	import mx.states.State;
	
	import org.apache.flex.core.IBead;
	import org.apache.flex.core.IParentIUIBase;
	import org.apache.flex.core.IStrand;
	import org.apache.flex.core.ValuesManager;
    import org.apache.flex.html.beads.ContainerView;
	import org.apache.flex.events.Event;
	import org.apache.flex.events.ValueChangeEvent;
	import org.apache.flex.utils.MXMLDataInterpreter;

    [DefaultProperty("mxmlContent")]
    
    /**
     *  The MXMLBeadViewBase class extends BeadViewBase
     *  and adds support for databinding and specification
     *  of children in MXML.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10.2
     *  @playerversion AIR 2.6
     *  @productversion FlexJS 0.0
     */
	public class MXMLBeadViewBase extends ContainerView implements IStrand, ILayoutParent
	{
        /**
         *  Constructor.
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
		public function MXMLBeadViewBase()
		{
			super();
		}
		
        [Bindable("strandChanged")]
        /**
         *  An MXMLBeadViewBase doesn't create its children until it is added to
         *  the strand.
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        override public function set strand(value:IStrand):void
        {
            super.strand = value;
            // each MXML file can also have styles in fx:Style block
            ValuesManager.valuesImpl.init(this);
            
            MXMLDataInterpreter.generateMXMLProperties(this, mxmlProperties);
            
            dispatchEvent(new Event("strandChanged"));            
            MXMLDataInterpreter.generateMXMLInstances(this, IParent(value), MXMLDescriptor);
            
            dispatchEvent(new Event("initComplete"))
            dispatchEvent(new Event("childrenAdded"));
        }
        
        /**
         *  @private
         *  Needed for databinding expressions
         */
        public function get strand():IStrand
        {
            return _strand;
        }
        
        [Bindable("__NoChangeEvent__")]
        /**
         *  The model object.
         */
        public function get model():Object
        {
            return _strand["model"];
        }
        
        /**
         *  @copy org.apache.flex.core.Application#MXMLDescriptor
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function get MXMLDescriptor():Array
        {
            return null;
        }
        
        private var mxmlProperties:Array ;
        
        /**
         *  @copy org.apache.flex.core.Application#generateMXMLAttributes()
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function generateMXMLAttributes(data:Array):void
        {
            mxmlProperties = data;
        }
        
        /**
         *  @copy org.apache.flex.core.ItemRendererClassFactory#mxmlContent
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public var mxmlContent:Array;
        
        private var _states:Array;
        
        /**
         *  The array of view states. These should
         *  be instances of mx.states.State.
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function get states():Array
        {
            return _states;
        }
        
        /**
         *  @private
         */
        public function set states(value:Array):void
        {
            _states = value;
            _currentState = _states[0].name;
            
            try{
                if (getBeadByType(IStatesImpl) == null)
                    addBead(new (ValuesManager.valuesImpl.getValue(this, "iStatesImpl")) as IBead);
            }
            //TODO:  Need to handle this case more gracefully
            catch(e:Error)
            {
                trace(e.message);
            }
            
        }
        
        /**
         *  <code>true</code> if the array of states
         *  contains a state with this name.
         * 
         *  @param state The state namem.
         *  @return True if state in state array
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function hasState(state:String):Boolean
        {
            for each (var s:State in _states)
            {
                if (s.name == state)
                    return true;
            }
            return false;
        }
        
        private var _currentState:String;
        
        /**
         *  The name of the current state.
         * 
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function get currentState():String
        {
            return _currentState;   
        }
        
        /**
         *  @private
         */
        public function set currentState(value:String):void
        {
            var event:ValueChangeEvent = new ValueChangeEvent("currentStateChanged", false, false, _currentState, value)
            _currentState = value;
            dispatchEvent(event);
        }
        
        private var _transitions:Array;
        
        /**
         *  The array of transitions.
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function get transitions():Array
        {
            return _transitions;   
        }
        
        /**
         *  @private
         */
        public function set transitions(value:Array):void
        {
            _transitions = value;   
        }

        /**
         *  @copy org.apache.flex.core.Application#beads
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public var beads:Array;
        
        private var _beads:Array;
        
        /**
         *  @copy org.apache.flex.core.IStrand#addBead()
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */        
        public function addBead(bead:IBead):void
        {
            if (!_beads)
                _beads = [];
            _beads.push(bead);
            bead.strand = this;            
        }
        
        /**
         *  @copy org.apache.flex.core.IStrand#getBeadByType()
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function getBeadByType(classOrInterface:Class):IBead
        {
            for each (var bead:IBead in _beads)
            {
                if (bead is classOrInterface)
                    return bead;
            }
            return null;
        }
        
        /**
         *  @copy org.apache.flex.core.IStrand#removeBead()
         *  
         *  @langversion 3.0
         *  @playerversion Flash 10.2
         *  @playerversion AIR 2.6
         *  @productversion FlexJS 0.0
         */
        public function removeBead(value:IBead):IBead	
        {
            var n:int = _beads.length;
            for (var i:int = 0; i < n; i++)
            {
                var bead:IBead = _beads[i];
                if (bead == value)
                {
                    _beads.splice(i, 1);
                    return bead;
                }
            }
            return null;
        }

    }
}