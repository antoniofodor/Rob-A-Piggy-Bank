class Paint:
    def __init__(self,name,base):
        self.mat=flat(name,base);self.nt=self.mat.node_tree;self.n=self.nt.nodes;self.l=self.nt.links
        self.bs=self.n.get('Principled BSDF')
        self.tex=self.n.new('ShaderNodeTexCoord').outputs['Object']
        n=self.n.new('ShaderNodeSeparateXYZ');self.l.new(self.tex,n.inputs[0])
        self.x,self.y,self.z=(n.outputs[k] for k in 'XYZ')
        self.color=self.rgb(base);self.glow=0;self.metal=0;self.rough=.65
    def rgb(self,v):
        n=self.n.new('ShaderNodeRGB');n.outputs[0].default_value=(*lin(v),1);return n.outputs[0]
    def wire(self,v,s):
        if isinstance(v,(int,float)):s.default_value=(v,v,v,1) if s.type=='RGBA' else v
        else:self.l.new(v,s)
    def op(self,kind,a,b=0):
        n=self.n.new('ShaderNodeMath');n.operation=kind;self.wire(a,n.inputs[0]);self.wire(b,n.inputs[1]);return n.outputs[0]
    def vec(self,x,y,z):
        n=self.n.new('ShaderNodeCombineXYZ')
        for v,s in zip((x,y,z),n.inputs):self.wire(v,s)
        return n.outputs[0]
    def noise(self,scale,detail=2,vec=None):
        n=self.n.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail;n.inputs['Roughness'].default_value=.55
        self.l.new(vec or self.tex,n.inputs['Vector']);return n.outputs['Fac']
    def vor(self,scale,feature='DISTANCE_TO_EDGE',vec=None):
        n=self.n.new('ShaderNodeTexVoronoi');n.feature=feature;n.inputs['Scale'].default_value=scale
        self.l.new(vec or self.tex,n.inputs['Vector']);return n
    def mix(self,a,b,f):
        n=self.n.new('ShaderNodeMixRGB');self.wire(f,n.inputs[0])
        for v,s in zip((a,b),n.inputs[1:3]):
            if isinstance(v,(list,tuple)):s.default_value=(*lin(v),1)
            else:self.l.new(v,s)
        return n.outputs[0]
    def ramp(self,f,colors,interpolation='LINEAR'):
        n=self.n.new('ShaderNodeValToRGB');n.color_ramp.interpolation=interpolation
        for i,c in enumerate(colors):
            e=n.color_ramp.elements[i] if i<2 else n.color_ramp.elements.new(i/(len(colors)-1))
            e.position=i/(len(colors)-1);e.color=(*lin(c),1)
        self.l.new(f,n.inputs[0]);return n.outputs['Color']
    def ellipse(self,axes,center,radii):
        d=0
        for a,c,r in zip(axes,center,radii):
            q=self.op('DIVIDE',self.op('SUBTRACT',a,c),r);d=self.op('ADD',d,self.op('MULTIPLY',q,q))
        return self.op('LESS_THAN',d,1)
    def stripe(self,phase,width):
        return self.op('LESS_THAN',self.op('ABSOLUTE',self.op('SINE',phase)),width)
    def finish(self):
        self.l.new(self.color,self.bs.inputs['Base Color']);self.l.new(self.color,self.bs.inputs['Emission Color'])
        self.wire(self.glow,self.bs.inputs['Emission Strength']);self.wire(self.metal,self.bs.inputs['Metallic']);self.wire(self.rough,self.bs.inputs['Roughness'])
        for label,value in [('BAKE_COLOR',self.color),('BAKE_EMISSIVE',self.glow),('BAKE_METAL',self.metal),('BAKE_ROUGH',self.rough)]:
            node=self.n.new('ShaderNodeEmission');node.label=label;node.name=label
            self.wire(value,node.inputs['Color'])
        return self.mat

