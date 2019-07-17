Shader "Custom/myPBR"
{
	Properties
	{
		_MainTex ("Base Color", 2D) = "white" {}
        _Color ("Color", Color) = (0.5019608,0.5019608,0.5019608,1)
        _Specular ("Specular", 2D) = "black" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _reflectmap ("reflectmap", Cube) = "_Skybox" {}
        _reflectionadd ("reflectionadd", Range(0, 10)) = 0
        _colovalue ("colovalue", Range(1, 2)) = 2
        _fresnelvalue ("fresnelvalue", float) = 2
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
		   Name "PBRFORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "UnityStandardBRDF.cginc"
			            #include "Lighting.cginc"
						#include "UnityPBSLighting.cginc"
						#include "AutoLight.cginc"

			uniform float4 _Color;
            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform sampler2D _BumpMap; uniform float4 _BumpMap_ST;
            uniform sampler2D _Specular; uniform float4 _Specular_ST;
            uniform float _reflectionadd;
            uniform samplerCUBE _reflectmap;
            uniform float _colovalue;
            uniform float _fresnelvalue;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv0 : TEXCOORD1;
				float2 uv1 : TEXCOORD2;

				float3 normal : NORMAL;
                float4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 uv0 : TEXCOORD1;
				float2 uv1 : TEXCOORD2;

				float4 vertex : SV_POSITION;
				float4 posWorld : TEXCOORD3;
				float3 normalDir : TEXCOORD4;
                float3 tangentDir : TEXCOORD5;
                float3 bitangentDir : TEXCOORD6;
				LIGHTING_COORDS(7,8)
				UNITY_FOG_COORDS(9)
				#if defined(LIGHTMAP_ON) || defined(UNITY_SHOULD_SAMPLE_SH)
				float4 ambientOrLightmapUV : TEXCOORD10;
				 #endif
			};
			
			v2f vert (appdata v)
			{
				v2f o= (v2f)0;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv0 = TRANSFORM_TEX(v.uv0, _Specular);
				//法线贴图
				o.uv1 = TRANSFORM_TEX(v.uv1, _BumpMap);

				o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
				//副切线
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);

                   //o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                   //o.ambientOrLightmapUV.zw = 0;
				UNITY_TRANSFER_FOG(o,o.vertex);
				                //TRANSFER_VERTEX_TO_FRAGMENT(o)
				return o;
			}
						
			fixed4 frag (v2f i) : COLOR
			{
			//环境光
				float attenuation = LIGHT_ATTENUATION(i);
                float3 attenColor = attenuation * _LightColor0.xyz;

				i.normalDir = normalize(i.normalDir);
				float3 normalDirection = i.normalDir;
				//切线空间到世界空间的变换矩阵
				float3x3 tangentTransform = float3x3(i.tangentDir,i.bitangentDir,i.normalDir);
				//法线贴图
				float3 bumpMap = UnpackNormal(tex2D(_BumpMap,i.uv1));
				//将法线的切线空间转到世界空间
				float3 bumpWorld = normalize( mul(bumpMap,tangentTransform));
				normalDirection = bumpWorld;
				float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);

				float NdotL = saturate(dot( normalDirection, lightDirection ));
				float NdotV = abs(dot( normalDirection, viewDirection ));
				float3 halfDirection = normalize(viewDirection+lightDirection);
				half NdotH = saturate(dot( normalDirection, halfDirection ));
                float LdotH = saturate(dot(lightDirection, halfDirection));

				//高光贴图
				fixed4 spcCol = tex2D(_Specular, i.uv0);
				float perceptualRoughness = 1.0 - spcCol.a;
				half roughness = perceptualRoughness*perceptualRoughness;
				float3 specularColor = spcCol.rgb;
                float gloss = spcCol.a;

				// sample the texture
				fixed4 mainTexCol = tex2D(_MainTex, i.uv);
				//float3 diffuseColor = 1.0-2.0*((mainTexCol.rgb*_Color.rgb)-0.5);
				//float3 diffuseColor = 2.0*(mainTexCol.rgb*_Color.rgb);
				float3 diffuseColor =_colovalue* mainTexCol.rgb*_Color.rgb;
				
				//GI
				float3 lightColor = _LightColor0.rgb;
				UnityLight light;

                light.color = lightColor;
                light.dir = lightDirection;
				light.ndotl = LambertTerm (normalDirection, light.dir);

				UnityGIInput d;
                d.light = light;
                d.worldPos = i.posWorld.xyz;
                d.worldViewDir = viewDirection;
				d.atten = attenuation;
                d.ambient = i.ambientOrLightmapUV;

			    d.probeHDR[0] = unity_SpecCube0_HDR;
                d.probeHDR[1] = unity_SpecCube1_HDR;

				float3 viewReflectDirection = reflect( -viewDirection, normalDirection );
				Unity_GlossyEnvironmentData ugls_en_data;
                ugls_en_data.roughness = 1.0 - gloss;
                ugls_en_data.reflUVW = viewReflectDirection;
				//全局光照，获取颜色和方向
                UnityGI gi = UnityGlobalIllumination(d, 1, normalDirection, ugls_en_data );
				lightDirection = gi.light.dir;
                lightColor = gi.light.color;

                float specularMonochrome;
                diffuseColor = EnergyConservationBetweenDiffuseAndSpecular(diffuseColor, specularColor, specularMonochrome);
				//这是最亮的颜色值
                specularMonochrome = 1.0-specularMonochrome;
				//BRDF d项

				half dCol = GGXTerm(NdotH,roughness);
				//G项
				half gTerm = SmithJointGGXVisibilityTerm(NdotH,NdotV,roughness);
				//F项
				half3 fCol = FresnelTerm(specularColor,LdotH);
				//测试
				float specularPBL = (dCol*gTerm) * UNITY_PI;
				//float specularPBL = dCol*gTerm;
				#ifdef UNITY_COLORSPACE_GAMMA
                    specularPBL = sqrt(max(1e-4h, specularPBL));
                #endif
				//不会为负数
				specularPBL = max(0, specularPBL * NdotL);
				//any 参数里的任意一个元素不为零
				specularPBL *= any(specularColor) ? 1.0 : 0.0;

				//half direSpec = dCol*gTerm*fCol;
				half direSpec = attenColor*specularPBL*fCol;

				half grazingTerm = saturate( gloss + specularMonochrome )*_fresnelvalue;
				//趋向grazingTerm，最大值
				//float3 indirectSpecular = FresnelLerp (specularColor, grazingTerm, NdotV);
				float3 indirectSpecular = gi.indirect.specular + spcCol.a*_reflectionadd;
				half surfaceReduction;
                #ifdef UNITY_COLORSPACE_GAMMA
                    surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;
                #else
                    surfaceReduction = 1.0/(roughness*roughness + 1.0);
                #endif
				indirectSpecular *= FresnelLerp (specularColor, grazingTerm, NdotV);
				indirectSpecular *= surfaceReduction;

                NdotL = max(0.0,dot( normalDirection, lightDirection ));
                half fd90 = 0.5 + 2 * LdotH * LdotH * (1-gloss);
                float nlPow5 = Pow5(1-NdotL);
                float nvPow5 = Pow5(1-NdotV);
				//直射漫反射，菲涅尔公式
                float3 directDiffuse = ((1 +(fd90 - 1)*nlPow5) * (1 + (fd90 - 1)*nvPow5) * NdotL) * attenColor;

				diffuseColor *= 1-specularMonochrome;

				float3 indirectDiffuse = float3(0,0,0);
				//全局光照非直射的漫反射
                indirectDiffuse += gi.indirect.diffuse;

				float3 finCol = (directDiffuse+indirectDiffuse)*diffuseColor + direSpec + indirectSpecular;
				//float3 finCol = diffuseColor + direSpec;
				float4 col = float4(finCol,0);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
