const assetPathPrefix = "https://www.figma.com/api/mcp/asset/9c69e7ab-49c7-4e8e-822e-9844dd05ea0e";
const imgGradient = `${assetPathPrefix}/d3751.png`;

export default function Gradient() {
  return (
    <div className="relative size-full" data-node-id="4012:5050" data-name="gradient">
      <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgGradient} />
    </div>
  );
}
SUPER CRITICAL: The generated React+Tailwind code MUST be converted to match the target project's technology stack and styling system.
1. Analyze the target codebase to identify: technology stack, styling approach, component patterns, and design tokens
2. Convert React syntax to the target framework/library
3. Transform all Tailwind classes to the target styling system while preserving exact visual design
4. Follow the project's existing patterns and conventions
DO NOT install any Tailwind as a dependency unless the user instructs you to do so.

Node ids have been added to the code as data attributes, e.g. `data-node-id="1:2"`.
The generated code contains image and SVG URL constants, e.g. const image = `${assetPathPrefix}/<asset file name>`, where assetPathPrefix is declared once at the top of the code and every asset URL interpolates it. These URLs are temporary download sources and expire after 7 days. Download each asset into the project with curl -L, then replace its URL in the generated code with a reference to the downloaded asset. Never use the temporary URLs as runtime image sources.